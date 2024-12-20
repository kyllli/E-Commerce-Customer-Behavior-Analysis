-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema electronics
-- -----------------------------------------------------
CREATE DATABASE IF NOT EXISTS `electronics` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `electronics`;

-- -----------------------------------------------------
-- Table `raw_data`
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS `raw_data` (
	`event_time` VARCHAR(255) DEFAULT NULL,
	`event_type` VARCHAR(255) DEFAULT NULL,
	`product_id` VARCHAR(255) DEFAULT NULL,
	`category_id` VARCHAR(255) DEFAULT NULL,
	`category_code` VARCHAR(255) DEFAULT NULL,
	`brand` VARCHAR(255) DEFAULT NULL,
	`price` VARCHAR(255) DEFAULT NULL,
	`user_id` VARCHAR(255) DEFAULT NULL,
	`user_session` VARCHAR(255) DEFAULT NULL
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Normalized tables
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS 	`times` (
	`event_time_id` INT NOT NULL AUTO_INCREMENT,
	`event_time` DATETIME NOT NULL,           -- Added for easier joins
	`event_year` YEAR(4) NOT NULL,
	`event_month` TINYINT(2) NOT NULL,
	`event_day` TINYINT(2) NOT NULL,
	`event_hms` TIME NOT NULL,
	PRIMARY KEY (`event_time_id`),
    UNIQUE KEY unique_event_time (event_time) -- Ensures event_time is unique
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `customers` (
    `user_session` VARCHAR(36) NOT NULL,
	`user_id` BIGINT(20) NOT NULL,
	PRIMARY KEY (`user_session`)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `categories` (
	`category_id` BIGINT(20) NOT NULL,
	`primary_category` VARCHAR(30) NOT NULL,
	`secondary_category` VARCHAR(30) DEFAULT NULL,
	`tertiary_category` VARCHAR(30) DEFAULT NULL,
	PRIMARY KEY (`category_id`)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `products` (
	`product_id` INT(6) NOT NULL,
	`brand` VARCHAR(50) NOT NULL,
	`price` DOUBLE NOT NULL,
	`category_id` BIGINT(20) NOT NULL,
	PRIMARY KEY (`product_id`),
	INDEX `category_id` (`category_id` ASC) VISIBLE,
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`category_id`)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `events` (
	`event_id` INT(9) NOT NULL AUTO_INCREMENT,
	`event_type` ENUM('view', 'cart', 'purchase') NOT NULL,
	`event_time_id` INT(6) NOT NULL,
	`product_id` INT(6) NOT NULL,
    `user_session` VARCHAR(36) NOT NULL,
	PRIMARY KEY (`event_id`),
	INDEX `event_time_id` (`event_time_id` ASC) VISIBLE,
	INDEX `user_session` (`user_session` ASC) VISIBLE,
	INDEX `product_id` (`product_id` ASC) VISIBLE,
    FOREIGN KEY (`event_time_id`) REFERENCES `times` (`event_time_id`),
    FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`),
    FOREIGN KEY (`user_session`) REFERENCES `customers` (`user_session`)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Inserting to normalized tables
-- -----------------------------------------------------

-- Insert into times table
INSERT INTO `times` (event_time, event_year, event_month, event_day, event_hms)
SELECT DISTINCT
    STR_TO_DATE(event_time, '%Y-%m-%d %H:%i:%s') AS event_time,
    YEAR(event_time) AS event_year,
    MONTH(event_time) AS event_month,
    DAY(event_time) AS event_day,
    TIME(event_time) AS event_hms
FROM raw_data
ON DUPLICATE KEY UPDATE
    event_time = VALUES(event_time),
    event_year = VALUES(event_year),
    event_month = VALUES(event_month),
    event_day = VALUES(event_day),
    event_hms = VALUES(event_hms);

-- Insert into customers table
INSERT INTO `customers` (user_id, user_session)
SELECT DISTINCT user_id, user_session
FROM raw_data
ON DUPLICATE KEY UPDATE
    user_id = VALUES(user_id);

-- Insert into categories table
INSERT INTO `categories` (category_id, primary_category, secondary_category, tertiary_category)
SELECT DISTINCT
    category_id,
    SUBSTRING_INDEX(category_code, '.', 1) AS primary_category,
    SUBSTRING_INDEX(SUBSTRING_INDEX(category_code, '.', 2), '.', -1) AS secondary_category,
    SUBSTRING_INDEX(category_code, '.', -1) AS tertiary_category
FROM raw_data
ON DUPLICATE KEY UPDATE
    primary_category = VALUES(primary_category),
    secondary_category = VALUES(secondary_category),
    tertiary_category = VALUES(tertiary_category);

-- Insert into products table
INSERT INTO `products` (product_id, brand, price, category_id)
SELECT DISTINCT
    cb.product_id,
    cb.brand,
    cb.price,
    cb.category_id
FROM raw_data cb
ON DUPLICATE KEY UPDATE
    brand = VALUES(brand),
    price = VALUES(price),
    category_id = VALUES(category_id);

-- Insert into events table
INSERT INTO `events` (event_type, event_time_id, product_id, user_session)
SELECT DISTINCT
    cb.event_type,
    et.event_time_id,
    cb.product_id,
    cb.user_session
FROM raw_data cb
JOIN times et
    ON cb.event_time = et.event_time
ON DUPLICATE KEY UPDATE
    event_type = VALUES(event_type),
    product_id = VALUES(product_id),
    user_session = VALUES(user_session);

-- Drop event_time (unnormalized) used for easier join
ALTER TABLE `times` DROP COLUMN `event_time`;