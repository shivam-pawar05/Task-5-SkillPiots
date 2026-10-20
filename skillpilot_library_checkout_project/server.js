require('dotenv').config();
const express = require('express');
const path = require('path');
const mysql = require('mysql2/promise');
const app = express();
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'skillpilot_library',
  waitForConnections: true, connectionLimit: 10
});
app.use(express.json());
app.use(express.static(path.join(__dirname,'public')));

app.get('/api/health', async (_req,res) => {
  try { await pool.query('SELECT 1'); res.json({status:'ok',database:'connected'}); }
  catch { res.status(503).json({status:'error',message:'Check .env and import database/schema.sql'}); }
});
app.get('/api/books', async (_req,res) => {
  try {
    const [books] = await pool.query(`
      SELECT b.book_id,b.title,b.author,b.isbn,b.status,m.full_name AS borrower
      FROM books b LEFT JOIN checkout_log c ON c.book_id=b.book_id AND c.status='CHECKED_OUT'
      LEFT JOIN members m ON m.member_id=c.member_id ORDER BY b.book_id`);
    res.json({books});
  } catch(e) { console.error(e); res.status(500).json({error:'Unable to load books. Check database setup.'}); }
});
app.get('/api/members', async (_req,res) => {
  try { const [members]=await pool.query('SELECT member_id,full_name,email FROM members WHERE is_active=TRUE ORDER BY full_name'); res.json({members}); }
  catch(e) { console.error(e); res.status(500).json({error:'Unable to load members.'}); }
});
app.post('/api/checkout', async (req,res) => {
  const book_id=Number(req.body?.book_id), member_id=Number(req.body?.member_id);
  if(!Number.isInteger(book_id)||book_id<=0||!Number.isInteger(member_id)||member_id<=0)
    return res.status(400).json({error:'Select a valid book and member.'});
  try {
    const [result]=await pool.query('CALL checkout_book(?,?)',[book_id,member_id]);
    res.json({ok:true,message:result?.[0]?.[0]?.message||'Checkout complete',checkout_id:result?.[0]?.[0]?.checkout_id});
  } catch(e) {
    const expected=e.sqlState==='45000'||e.code==='ER_SIGNAL_EXCEPTION';
    res.status(expected?400:500).json({error:expected?(e.sqlMessage||e.message):'Database error. The transaction was rolled back.'});
  }
});
app.post('/api/return', async (req,res) => {
  const book_id=Number(req.body?.book_id);
  if(!Number.isInteger(book_id)||book_id<=0) return res.status(400).json({error:'Select a valid book.'});
  try { const [result]=await pool.query('CALL return_book(?)',[book_id]); res.json({ok:true,message:result?.[0]?.[0]?.message||'Book returned'}); }
  catch(e) { res.status(e.sqlState==='45000'?400:500).json({error:e.sqlMessage||e.message||'Return failed'}); }
});
app.get('/api/history', async (_req,res) => {
  try {
    const [history]=await pool.query(`SELECT c.checkout_id,b.title,m.full_name,c.checked_out_at,c.returned_at,c.status
      FROM checkout_log c JOIN books b ON b.book_id=c.book_id JOIN members m ON m.member_id=c.member_id
      ORDER BY c.checkout_id DESC LIMIT 100`);
    res.json({history});
  } catch(e) { console.error(e); res.status(500).json({error:'Unable to load history.'}); }
});
app.get('*',(_req,res)=>res.sendFile(path.join(__dirname,'public','index.html')));
const port=Number(process.env.PORT||3000);
app.listen(port,()=>console.log(`Library app: http://localhost:${port}`));
