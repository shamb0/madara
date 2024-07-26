use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use chrono::NaiveDate;
use sqlx::{postgres::PgPoolOptions, PgPool};

use crate::types::{LatestTransaction, LatestTransactionsParams, Transaction, MAX_DB_CONNECTIONS};

#[derive(Clone)]
struct AppState {
    db: PgPool,
}

pub async fn start_app_server(api_port: u16, database_url: &str) -> anyhow::Result<()> {
    let db = PgPoolOptions::new()
        .max_connections(MAX_DB_CONNECTIONS)
        .connect(database_url)
        .await
        .expect("Failed to create pool");

    // Create app state
    let state = Arc::new(AppState { db });

    // Build our application with routes
    let app = Router::new()
        .route("/transactions/by-id/:signature", get(get_transaction_by_id))
        .route("/transactions/by-date/:date", get(get_transactions_by_date))
        .route("/transactions/latest", get(get_latest_transactions))
        .with_state(state);

    // Run it
    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], api_port));
    println!("Listening on {}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

async fn get_transaction_by_id(
    State(state): State<Arc<AppState>>,
    Path(signature): Path<String>,
) -> Result<Json<Option<Transaction>>, (StatusCode, String)> {
    let transaction = sqlx::query_as!(
        Transaction,
        r#"
        SELECT signature, timestamp, slot, fee, fee_payer, transaction_type, transaction
        FROM sol_transactions
        WHERE signature = $1
        "#,
        signature
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(transaction))
}

async fn get_transactions_by_date(
    State(state): State<Arc<AppState>>,
    Path(date): Path<String>,
) -> Result<Json<Vec<Transaction>>, (StatusCode, String)> {
    tracing::info!("Received request for transactions on date: {}", date);

    let date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            format!("Invalid date format: {}", e),
        )
    })?;

    let transactions = sqlx::query_as!(
        Transaction,
        r#"
        SELECT signature, timestamp, slot, fee, fee_payer, transaction_type, transaction
        FROM sol_transactions
        WHERE date = $1
        "#,
        date
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if transactions.is_empty() {
        return Err((
            StatusCode::NOT_FOUND,
            format!("No transactions found for date: {}", date),
        ));
    }

    tracing::info!(
        "Found {} transactions for date: {}",
        transactions.len(),
        date
    );

    Ok(Json(transactions))
}

async fn get_latest_transactions(
    State(state): State<Arc<AppState>>,
    Query(params): Query<LatestTransactionsParams>,
) -> Result<Json<Vec<LatestTransaction>>, (StatusCode, String)> {
    let count = params.count.unwrap_or(5).min(100); // Default to 5, max 100

    let transactions = sqlx::query_as!(
        LatestTransaction,
        r#"
        SELECT timestamp, signature, slot
        FROM sol_transactions
        ORDER BY timestamp DESC
        LIMIT $1
        "#,
        count as i64
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(transactions))
}
