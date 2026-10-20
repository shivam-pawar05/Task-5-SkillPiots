# SkillPilot Library Checkout Management

A full-stack library management project matching the SkillPilot task: create a procedure that checks out a book, updates the borrower record, logs the transaction, commits on success, and rolls back on SQL errors.

## Technology
- HTML5, CSS3, JavaScript
- Node.js + Express
- MySQL 8+
- MySQL stored procedures and transactions

## Requirements
Install Node.js 18+, MySQL 8+, and npm. MySQL Workbench is optional.

## Run on Windows
1. Extract the ZIP and open the folder in VS Code.
2. Open a terminal in this folder and run `npm install`.
3. Copy `.env.example` to `.env` and set your local MySQL username/password.
   PowerShell command: `Copy-Item .env.example .env`
4. Import `database/schema.sql` using MySQL Workbench, or run `mysql -u root -p < database/schema.sql`.
5. Start the app using `npm start`.
6. Open http://localhost:3000 in your browser.

## Task steps mapped to code
1. Input parameters: `checkout_book(IN p_book_id INT, IN p_member_id INT)`.
2. Availability: `SELECT status ... FOR UPDATE` locks the book while checking it.
3. Logging/status: insert into `checkout_log`, then update `books.status`.
4. Commit: `COMMIT` runs after both database writes succeed.
5. Exception handling: an `EXIT HANDLER FOR SQLEXCEPTION` runs `ROLLBACK` and `RESIGNAL`.

## Demo data
Five sample books and three active members are inserted by the SQL script. No login is required for this local educational demo.

## API endpoints
- `GET /api/health` — verify MySQL connection
- `GET /api/books` — list books and current borrower
- `GET /api/members` — list active members
- `POST /api/checkout` — call the checkout stored procedure
- `POST /api/return` — return a book
- `GET /api/history` — show transaction history

Example checkout JSON: `{"book_id":1,"member_id":1}`

## Testing
1. Check out a book from the Books & Checkout tab.
2. Verify its status changes to Checked out.
3. Open Transaction History and verify a log entry exists.
4. Attempt to check out the same book again; it should be rejected.
5. Return the book and verify it becomes available again.
6. Try a nonexistent book ID through an API client; it should return an error without partial database changes.

## Notes
This project is intended for a local educational submission. Before production use, add authentication, authorization, rate limiting, HTTPS, backups, and restricted database grants. Keep credentials in `.env` and never commit that file.
