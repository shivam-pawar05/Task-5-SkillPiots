CREATE DATABASE IF NOT EXISTS skillpilot_library;
USE skillpilot_library;

CREATE TABLE IF NOT EXISTS books (
  book_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  author VARCHAR(160) NOT NULL,
  isbn VARCHAR(30),
  status ENUM('AVAILABLE','CHECKED_OUT') NOT NULL DEFAULT 'AVAILABLE'
);
CREATE TABLE IF NOT EXISTS members (
  member_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(160) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS checkout_log (
  checkout_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  book_id INT NOT NULL,
  member_id INT NOT NULL,
  checked_out_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  returned_at TIMESTAMP NULL,
  status ENUM('CHECKED_OUT','RETURNED') NOT NULL DEFAULT 'CHECKED_OUT',
  FOREIGN KEY (book_id) REFERENCES books(book_id),
  FOREIGN KEY (member_id) REFERENCES members(member_id)
);

INSERT IGNORE INTO books(book_id,title,author,isbn,status) VALUES
(1,'The Alchemist','Paulo Coelho','9780062315007','AVAILABLE'),
(2,'Wings of Fire','A. P. J. Abdul Kalam','9788173711466','AVAILABLE'),
(3,'Clean Code','Robert C. Martin','9780132350884','AVAILABLE'),
(4,'Database System Concepts','Abraham Silberschatz','9780078022159','AVAILABLE'),
(5,'Atomic Habits','James Clear','9780735211292','AVAILABLE');

INSERT IGNORE INTO members(member_id,full_name,email,is_active) VALUES
(1,'Aarav Sharma','aarav@example.com',TRUE),
(2,'Priya Patil','priya@example.com',TRUE),
(3,'Rohan Deshmukh','rohan@example.com',TRUE);

DROP PROCEDURE IF EXISTS checkout_book;
DELIMITER $$
CREATE PROCEDURE checkout_book(IN p_book_id INT, IN p_member_id INT)
BEGIN
  DECLARE v_book_status VARCHAR(20) DEFAULT NULL;
  DECLARE v_member_active BOOLEAN DEFAULT NULL;
  DECLARE v_active_checkout BIGINT DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_book_id IS NULL OR p_member_id IS NULL OR p_book_id <= 0 OR p_member_id <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='book_id and member_id must be positive integers';
  END IF;

  START TRANSACTION;
  SELECT status INTO v_book_status FROM books WHERE book_id=p_book_id FOR UPDATE;
  IF v_book_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Book not found';
  END IF;

  SELECT is_active INTO v_member_active FROM members WHERE member_id=p_member_id FOR UPDATE;
  IF v_member_active IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Member not found';
  END IF;
  IF v_member_active=FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Member account is inactive';
  END IF;
  IF v_book_status <> 'AVAILABLE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Book is not available for checkout';
  END IF;

  SELECT checkout_id INTO v_active_checkout FROM checkout_log
    WHERE book_id=p_book_id AND status='CHECKED_OUT' LIMIT 1;
  IF v_active_checkout IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='An active checkout already exists';
  END IF;

  INSERT INTO checkout_log(book_id,member_id,status) VALUES(p_book_id,p_member_id,'CHECKED_OUT');
  UPDATE books SET status='CHECKED_OUT' WHERE book_id=p_book_id;
  COMMIT;
  SELECT 'SUCCESS' AS result,'Book checked out and transaction committed' AS message,
         LAST_INSERT_ID() AS checkout_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS return_book;
DELIMITER $$
CREATE PROCEDURE return_book(IN p_book_id INT)
BEGIN
  DECLARE v_book_id INT DEFAULT NULL;
  DECLARE v_checkout_id BIGINT DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  START TRANSACTION;
  SELECT book_id INTO v_book_id FROM books WHERE book_id=p_book_id FOR UPDATE;
  IF v_book_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Book not found';
  END IF;
  SELECT checkout_id INTO v_checkout_id FROM checkout_log
    WHERE book_id=p_book_id AND status='CHECKED_OUT' ORDER BY checkout_id DESC LIMIT 1;
  IF v_checkout_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='No active checkout for this book';
  END IF;
  UPDATE checkout_log SET status='RETURNED',returned_at=CURRENT_TIMESTAMP WHERE checkout_id=v_checkout_id;
  UPDATE books SET status='AVAILABLE' WHERE book_id=p_book_id;
  COMMIT;
  SELECT 'SUCCESS' AS result,'Book returned successfully' AS message;
END$$
DELIMITER ;
