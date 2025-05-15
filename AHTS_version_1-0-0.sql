-- ============================================
-- Copyright 2025 Adaptive Horizons Tech Solutions B.V.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================
--
-- ============================================
-- DATABASE SCHEMA (Version 1.0.0 - Initial Structure)
-- ============================================
-- Central 'companies' table.
-- Departments link to companies.
-- Addresses link MANDATORILY to Companies, OPTIONALLY to Departments.
-- Contacts link optionally to Addresses, and via Junctions to Companies, Departments, or Roles.
-- Market Segments link Many-to-Many with Companies.
-- Includes Soft Delete for core entities.
-- Utilizes Generated Columns for Active Unique Constraints.
-- Includes enhanced Currency Handling & Lookup Tables for Statuses.
-- Adds optional Exchange Rates table.
-- Includes DB Triggers for:
--   - Address-Department-Company consistency.
--   - Preventing multiple Primary Addresses per owner.
--   - Preventing multiple Primary Contacts per Role link.
-- Includes explicit user tracking for key documents (Leads, Quotes, Orders, Invoices).
-- Includes a 'db_schema_version' table for queryable schema version tracking with checksum.
-- NOTE: Application Logic still recommended for:
--       - Company Role validity on transactions (e.g., Order requires Customer role).
--       - Ensuring at least one Department exists per Company upon creation.
-- ============================================

-- ============================================
-- SETUP
-- ============================================
SET FOREIGN_KEY_CHECKS=0; -- Disable FK checks temporarily
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION";
SET time_zone = "+00:00"; -- Use UTC

-- Drop Views FIRST
DROP VIEW IF EXISTS `view_active_users`;
DROP VIEW IF EXISTS `view_active_companies`;
DROP VIEW IF EXISTS `view_active_departments`;
DROP VIEW IF EXISTS `view_active_customers`;
DROP VIEW IF EXISTS `view_active_suppliers`;
DROP VIEW IF EXISTS `view_active_partners`;
DROP VIEW IF EXISTS `view_active_products`;
DROP VIEW IF EXISTS `view_active_contacts`;
DROP VIEW IF EXISTS `view_active_addresses`;
DROP VIEW IF EXISTS `view_low_stock_alert`;
DROP VIEW IF EXISTS `view_sales_by_country_month`;
DROP VIEW IF EXISTS `view_overdue_customer_invoices`;

-- Drop Triggers FIRST (if they exist from previous runs)
DROP TRIGGER IF EXISTS `addr_consistency_before_insert`;
DROP TRIGGER IF EXISTS `addr_consistency_before_update`;
DROP TRIGGER IF EXISTS `addr_enforce_single_primary_insert`;
DROP TRIGGER IF EXISTS `addr_enforce_single_primary_update`;
DROP TRIGGER IF EXISTS `cust_contact_single_primary_insert`;
DROP TRIGGER IF EXISTS `cust_contact_single_primary_update`;
DROP TRIGGER IF EXISTS `supp_contact_single_primary_insert`;
DROP TRIGGER IF EXISTS `supp_contact_single_primary_update`;
DROP TRIGGER IF EXISTS `part_contact_single_primary_insert`;
DROP TRIGGER IF EXISTS `part_contact_single_primary_update`;

-- Drop Junction Tables & Dependent Tables FIRST
DROP TABLE IF EXISTS `customer_contacts`;
DROP TABLE IF EXISTS `supplier_contacts`;
DROP TABLE IF EXISTS `partner_contacts`;
DROP TABLE IF EXISTS `company_contacts`;
DROP TABLE IF EXISTS `department_contacts`;
DROP TABLE IF EXISTS `contact_expertise`;
DROP TABLE IF EXISTS `expertise_tags`;
DROP TABLE IF EXISTS `company_market_segments`;
DROP TABLE IF EXISTS `support_tickets`;
DROP TABLE IF EXISTS `contacts`;
DROP TABLE IF EXISTS `addresses`;
DROP TABLE IF EXISTS `lead_attachments`;
DROP TABLE IF EXISTS `tender_attachments`;
DROP TABLE IF EXISTS `quote_customer_attachments`;
DROP TABLE IF EXISTS `purchase_order_attachments`;
DROP TABLE IF EXISTS `invoice_customer_attachments`;
DROP TABLE IF EXISTS `invoice_supplier_attachments`;
DROP TABLE IF EXISTS `attachments`;
DROP TABLE IF EXISTS `rma_items`;
DROP TABLE IF EXISTS `rmas`;
DROP TABLE IF EXISTS `payments`;
DROP TABLE IF EXISTS `invoices_supplier`;
DROP TABLE IF EXISTS `invoices_customer`;
DROP TABLE IF EXISTS `shipment_items`;
DROP TABLE IF EXISTS `shipments`;
DROP TABLE IF EXISTS `serial_numbers`;
DROP TABLE IF EXISTS `stock_levels`;
DROP TABLE IF EXISTS `purchase_order_items`;
DROP TABLE IF EXISTS `purchase_orders`;
DROP TABLE IF EXISTS `quote_supplier_items`;
DROP TABLE IF EXISTS `quotes_supplier`;
DROP TABLE IF EXISTS `order_items`;
DROP TABLE IF EXISTS `orders`;
DROP TABLE IF EXISTS `quote_customer_items`;
DROP TABLE IF EXISTS `quotes_customer`;
DROP TABLE IF EXISTS `tenders`;
DROP TABLE IF EXISTS `leads`;
DROP TABLE IF EXISTS `partners`;
DROP TABLE IF EXISTS `customers`;
DROP TABLE IF EXISTS `suppliers`;
DROP TABLE IF EXISTS `departments`;
DROP TABLE IF EXISTS `companies`;
DROP TABLE IF EXISTS `products`;
DROP TABLE IF EXISTS `product_categories`;
DROP TABLE IF EXISTS `warehouses`;
DROP TABLE IF EXISTS `market_segments`;
DROP TABLE IF EXISTS `role_permissions`;
DROP TABLE IF EXISTS `permissions`;
DROP TABLE IF EXISTS `user_roles`;
DROP TABLE IF EXISTS `roles`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `exchange_rates`;
DROP TABLE IF EXISTS `currencies`;
DROP TABLE IF EXISTS `countries`;

-- Drop Status/Lookup Tables
DROP TABLE IF EXISTS `customer_account_statuses`;
DROP TABLE IF EXISTS `lead_statuses`;
DROP TABLE IF EXISTS `tender_statuses`;
DROP TABLE IF EXISTS `quote_statuses`;
DROP TABLE IF EXISTS `order_statuses`;
DROP TABLE IF EXISTS `payment_statuses`;
DROP TABLE IF EXISTS `shipment_statuses`;
DROP TABLE IF EXISTS `po_statuses`;
DROP TABLE IF EXISTS `invoice_statuses`;
DROP TABLE IF EXISTS `supplier_invoice_statuses`;
DROP TABLE IF EXISTS `serial_number_statuses`;
DROP TABLE IF EXISTS `rma_statuses`;
DROP TABLE IF EXISTS `rma_item_conditions`;
DROP TABLE IF EXISTS `rma_item_actions`;
DROP TABLE IF EXISTS `ticket_statuses`;
DROP TABLE IF EXISTS `ticket_priorities`;
DROP TABLE IF EXISTS `partner_types`;
DROP TABLE IF EXISTS `db_schema_version`;

-- ============================================
-- REFERENCE DATA TABLES
-- ============================================
CREATE TABLE `countries` ( `country_id` INT AUTO_INCREMENT PRIMARY KEY, `country_name` VARCHAR(100) NOT NULL UNIQUE, `country_code_iso2` CHAR(2) NOT NULL UNIQUE, `region` VARCHAR(50) NULL, INDEX `idx_country_code` (`country_code_iso2`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `currencies` ( `currency_code` CHAR(3) PRIMARY KEY, `currency_name` VARCHAR(100) NOT NULL, `symbol` VARCHAR(5) NULL, `decimal_places` TINYINT UNSIGNED NOT NULL DEFAULT 2, `is_active` BOOLEAN NOT NULL DEFAULT TRUE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `market_segments` ( `segment_id` INT AUTO_INCREMENT PRIMARY KEY, `segment_name` VARCHAR(100) NOT NULL UNIQUE, `description` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `expertise_tags` ( `tag_id` INT AUTO_INCREMENT PRIMARY KEY, `tag_name` VARCHAR(100) NOT NULL UNIQUE, `description` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `roles` ( `role_id` INT AUTO_INCREMENT PRIMARY KEY, `role_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `permissions` ( `permission_id` INT AUTO_INCREMENT PRIMARY KEY, `permission_name` VARCHAR(100) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `product_categories` ( `category_id` INT AUTO_INCREMENT PRIMARY KEY, `category_name` VARCHAR(100) NOT NULL UNIQUE, `description` TEXT NULL, `parent_category_id` INT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`parent_category_id`) REFERENCES `product_categories`(`category_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_category_name` (`category_name`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `warehouses` ( `warehouse_id` INT AUTO_INCREMENT PRIMARY KEY, `warehouse_name` VARCHAR(100) NOT NULL UNIQUE, `address_line1` VARCHAR(255) NULL, `address_line2` VARCHAR(255) NULL, `city` VARCHAR(100) NULL, `state_province` VARCHAR(100) NULL, `postal_code` VARCHAR(20) NULL, `country_id` INT NULL, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`country_id`) REFERENCES `countries`(`country_id`) ON DELETE SET NULL ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SCHEMA VERSION TABLE
-- ============================================
CREATE TABLE `db_schema_version` (
    `version_id` INT AUTO_INCREMENT PRIMARY KEY,
    `version_tag` VARCHAR(50) NOT NULL UNIQUE COMMENT 'e.g., 1.0.0, 1.0.1-feature-xyz',
    `description` TEXT NULL COMMENT 'Brief description of changes in this version',
    `applied_by` VARCHAR(100) NULL COMMENT 'User or script that applied this version',
    `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when this version script was run',
    `script_checksum_algo` VARCHAR(10) NULL COMMENT 'Algorithm used for checksum (e.g., MD5, SHA256)',
    `script_checksum` VARCHAR(128) NULL COMMENT 'Checksum of the applied SQL script (calculated on script with placeholder)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks the applied versions of the database schema.';

-- Insert the current version defined by this script
-- IMPORTANT:
-- 1. This script should contain '%%SCRIPT_CHECKSUM_PLACEHOLDER%%' for the script_checksum value
--    AND '_YOUR_SCRIPT_CHECKSUM_ALGO_HERE_' for the script_checksum_algo value
--    WHEN its checksum is calculated.
-- 2. Before execution, these placeholders must be replaced with:
--    - The chosen algorithm (e.g., 'SHA256') for _YOUR_SCRIPT_CHECKSUM_ALGO_HERE_.
--    - The checksum (calculated in step 1) for %%SCRIPT_CHECKSUM_PLACEHOLDER%%.
INSERT INTO `db_schema_version` (`version_tag`, `description`, `applied_by`, `script_checksum_algo`, `script_checksum`)
VALUES ('1.0.0', 'Initial schema structure. Baseline for the application.', 'Arild Saether', 'SHA256', '%%SCRIPT_CHECKSUM_PLACEHOLDER%%');


-- ============================================
-- STATUS / LOOKUP TABLES
-- ============================================
CREATE TABLE `customer_account_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `lead_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL, `sequence` TINYINT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tender_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL, `sequence` TINYINT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `quote_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `order_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `payment_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `shipment_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `po_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `invoice_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `supplier_invoice_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `serial_number_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `rma_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `rma_item_conditions` ( `condition_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `condition_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `rma_item_actions` ( `action_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `action_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `ticket_statuses` ( `status_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `status_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `ticket_priorities` ( `priority_id` TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `priority_name` VARCHAR(50) NOT NULL UNIQUE, `description` VARCHAR(255) NULL, `level` TINYINT NOT NULL UNIQUE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `partner_types` ( `type_id` INT AUTO_INCREMENT PRIMARY KEY, `type_name` VARCHAR(100) NOT NULL UNIQUE, `description` TEXT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- CORE ENTITY TABLES
-- ============================================
CREATE TABLE `users` ( `user_id` INT AUTO_INCREMENT PRIMARY KEY, `first_name` VARCHAR(100) NOT NULL, `last_name` VARCHAR(100) NOT NULL, `email` VARCHAR(255) NOT NULL, `password_hash` VARCHAR(255) NOT NULL, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL, `active_email` VARCHAR(255) GENERATED ALWAYS AS (IF(is_deleted, NULL, email)) STORED, INDEX `idx_user_email_raw` (`email`), INDEX `idx_user_deleted` (`is_deleted`), INDEX `idx_user_deleted_active` (`is_deleted`, `is_active`), UNIQUE KEY `uq_users_active_email` (`active_email`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Employees using the system';

CREATE TABLE `companies` ( `company_id` INT AUTO_INCREMENT PRIMARY KEY, `company_name` VARCHAR(255) NOT NULL, `vat_number` VARCHAR(50) NULL, `website` VARCHAR(255) NULL, `default_payment_terms` VARCHAR(100) NULL, `preferred_currency_code` CHAR(3) NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL, `active_company_name` VARCHAR(255) GENERATED ALWAYS AS (IF(is_deleted, NULL, company_name)) STORED, INDEX `idx_company_name_raw` (`company_name`), INDEX `idx_company_deleted` (`is_deleted`), UNIQUE KEY `uq_companies_active_name` (`active_company_name`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Central entity for all external organizations';

CREATE TABLE `departments` ( `department_id` INT AUTO_INCREMENT PRIMARY KEY, `company_id` INT NOT NULL, `department_name` VARCHAR(150) NOT NULL, `parent_department_id` INT NULL, `default_contact_id` INT NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`parent_department_id`) REFERENCES `departments`(`department_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_dept_company` (`company_id`), INDEX `idx_dept_name` (`company_id`, `department_name`), INDEX `idx_dept_deleted` (`is_deleted`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Departments within a company. App should ensure at least one exists per company.';

CREATE TABLE `products` ( `product_id` INT AUTO_INCREMENT PRIMARY KEY, `sku` VARCHAR(50) NOT NULL, `product_name` VARCHAR(255) NOT NULL, `description` TEXT NULL, `category_id` INT NULL, `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00, `currency_code` CHAR(3) NOT NULL, `default_cost_price` DECIMAL(12, 2) NULL, `default_cost_currency_code` CHAR(3) NULL, `weight_kg` DECIMAL(8, 3) NULL, `dimensions_cm` VARCHAR(50) NULL, `datasheet_url` VARCHAR(512) NULL, `track_serial_number` BOOLEAN NOT NULL DEFAULT FALSE, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL, `active_sku` VARCHAR(50) GENERATED ALWAYS AS (IF(is_deleted, NULL, sku)) STORED, FOREIGN KEY (`category_id`) REFERENCES `product_categories`(`category_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_product_sku_raw` (`sku`), INDEX `idx_product_name` (`product_name`), INDEX `idx_product_category` (`category_id`), INDEX `idx_product_deleted` (`is_deleted`), INDEX `idx_product_deleted_active_category` (`is_deleted`, `is_active`, `category_id`), UNIQUE KEY `uq_products_active_sku` (`active_sku`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Products';

CREATE TABLE `addresses` (
    `address_id` INT AUTO_INCREMENT PRIMARY KEY,
    `company_id` INT NOT NULL COMMENT 'The company this address belongs to (Mandatory)',
    `owner_department_id` INT NULL COMMENT 'Optional: Specific department using this address (Must belong to company_id - Enforced via Trigger)',
    `address_type` ENUM('Billing', 'Shipping', 'Office', 'Other') NOT NULL,
    `address_name` VARCHAR(150) NULL,
    `is_primary_billing_for_owner` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Primary billing for owner (Company if dept NULL, else Dept). Uniqueness enforced via Trigger.',
    `is_primary_shipping_for_owner` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Primary shipping for owner (Company if dept NULL, else Dept). Uniqueness enforced via Trigger.',
    `address_line1` VARCHAR(255) NULL, `address_line2` VARCHAR(255) NULL, `city` VARCHAR(100) NULL, `state_province` VARCHAR(100) NULL, `postal_code` VARCHAR(20) NULL,
    `country_id` INT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`owner_department_id`) REFERENCES `departments`(`department_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`country_id`) REFERENCES `countries`(`country_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_address_company` (`company_id`), INDEX `idx_address_dept_owner` (`owner_department_id`), INDEX `idx_address_type` (`address_type`), INDEX `idx_address_deleted` (`is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Addresses, linked to Companies and optionally Departments';

CREATE TABLE `contacts` ( `contact_id` INT AUTO_INCREMENT PRIMARY KEY, `first_name` VARCHAR(100) NOT NULL, `last_name` VARCHAR(100) NULL, `job_title` VARCHAR(100) NULL, `email` VARCHAR(255) NULL, `phone_work` VARCHAR(50) NULL, `phone_mobile` VARCHAR(50) NULL, `address_id` INT NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, `deleted_at` TIMESTAMP NULL DEFAULT NULL, `active_email` VARCHAR(255) GENERATED ALWAYS AS (IF(is_deleted OR email IS NULL, NULL, email)) STORED, FOREIGN KEY (`address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_contact_email_raw` (`email`), INDEX `idx_contact_name` (`last_name`, `first_name`), INDEX `idx_contact_deleted` (`is_deleted`), UNIQUE KEY `uq_contacts_active_email` (`active_email`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Central table for contact persons';

ALTER TABLE `departments` ADD CONSTRAINT `fk_dept_default_contact` FOREIGN KEY (`default_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================
-- COMPANY ROLE TABLES
-- ============================================
CREATE TABLE `customers` ( `customer_id` INT AUTO_INCREMENT PRIMARY KEY, `company_id` INT NOT NULL UNIQUE, `account_manager_id` INT NULL, `account_status_id` TINYINT UNSIGNED NOT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`account_manager_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`account_status_id`) REFERENCES `customer_account_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, INDEX `idx_customer_company` (`company_id`), INDEX `idx_customer_account_manager` (`account_manager_id`), INDEX `idx_customer_status` (`account_status_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `suppliers` ( `supplier_id` INT AUTO_INCREMENT PRIMARY KEY, `company_id` INT NOT NULL UNIQUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_supplier_company` (`company_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `partners` ( `partner_id` INT AUTO_INCREMENT PRIMARY KEY, `company_id` INT NOT NULL UNIQUE, `partner_type_id` INT NULL, `partnership_level` VARCHAR(50) NULL, `agreement_url` VARCHAR(512) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`partner_type_id`) REFERENCES `partner_types`(`type_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_partner_company` (`company_id`), INDEX `idx_partner_type` (`partner_type_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- JUNCTION & DEPENDENT TABLES
-- ============================================
CREATE TABLE `user_roles` ( `user_id` INT NOT NULL, `role_id` INT NOT NULL, PRIMARY KEY (`user_id`, `role_id`), FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`role_id`) REFERENCES `roles`(`role_id`) ON DELETE CASCADE ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `role_permissions` ( `role_id` INT NOT NULL, `permission_id` INT NOT NULL, PRIMARY KEY (`role_id`, `permission_id`), FOREIGN KEY (`role_id`) REFERENCES `roles`(`role_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`permission_id`) REFERENCES `permissions`(`permission_id`) ON DELETE CASCADE ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `company_market_segments` ( `company_id` INT NOT NULL, `segment_id` INT NOT NULL, PRIMARY KEY (`company_id`, `segment_id`), FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`segment_id`) REFERENCES `market_segments`(`segment_id`) ON DELETE CASCADE ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `customer_contacts` ( `customer_id` INT NOT NULL, `contact_id` INT NOT NULL, `is_primary_for_customer` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Uniqueness per customer_id enforced via Trigger', `role_description` VARCHAR(100) NULL, PRIMARY KEY (`customer_id`, `contact_id`), FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_customercontacts_contact` (`contact_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `supplier_contacts` ( `supplier_id` INT NOT NULL, `contact_id` INT NOT NULL, `is_primary_for_supplier` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Uniqueness per supplier_id enforced via Trigger', `role_description` VARCHAR(100) NULL, PRIMARY KEY (`supplier_id`, `contact_id`), FOREIGN KEY (`supplier_id`) REFERENCES `suppliers`(`supplier_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_suppliercontacts_contact` (`contact_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `partner_contacts` ( `partner_id` INT NOT NULL, `contact_id` INT NOT NULL, `is_primary_for_partner` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Uniqueness per partner_id enforced via Trigger', `role_description` VARCHAR(100) NULL, PRIMARY KEY (`partner_id`, `contact_id`), FOREIGN KEY (`partner_id`) REFERENCES `partners`(`partner_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_partnercontacts_contact` (`contact_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `company_contacts` ( `company_id` INT NOT NULL, `contact_id` INT NOT NULL, `role_description` VARCHAR(100) NULL, PRIMARY KEY (`company_id`, `contact_id`), FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_companycontacts_contact` (`contact_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `department_contacts` ( `department_id` INT NOT NULL, `contact_id` INT NOT NULL, `role_description` VARCHAR(100) NULL, PRIMARY KEY (`department_id`, `contact_id`), FOREIGN KEY (`department_id`) REFERENCES `departments`(`department_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, INDEX `idx_departmentcontacts_contact` (`contact_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `contact_expertise` ( `contact_id` INT NOT NULL, `tag_id` INT NOT NULL, PRIMARY KEY (`contact_id`, `tag_id`), FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`tag_id`) REFERENCES `expertise_tags`(`tag_id`) ON DELETE CASCADE ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `stock_levels` ( `stock_level_id` INT AUTO_INCREMENT PRIMARY KEY, `product_id` INT NOT NULL, `warehouse_id` INT NOT NULL, `quantity_on_hand` INT NOT NULL DEFAULT 0, `quantity_reserved` INT NOT NULL DEFAULT 0, `quantity_on_order` INT NOT NULL DEFAULT 0, `quantity_available` INT AS (`quantity_on_hand` - `quantity_reserved`) STORED, `quantity_projected` INT AS (`quantity_on_hand` - `quantity_reserved` + `quantity_on_order`) STORED, `reorder_level` INT UNSIGNED NULL, `location_bin` VARCHAR(50) NULL, `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE KEY `uq_product_warehouse` (`product_id`, `warehouse_id`), FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses`(`warehouse_id`) ON DELETE RESTRICT ON UPDATE CASCADE, INDEX `idx_stock_quantity_available` (`quantity_available`), INDEX `idx_stock_warehouse` (`warehouse_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `exchange_rates` ( `rate_id` INT AUTO_INCREMENT PRIMARY KEY, `from_currency_code` CHAR(3) NOT NULL, `to_currency_code` CHAR(3) NOT NULL, `rate` DECIMAL(18, 8) NOT NULL, `effective_date` DATE NOT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY `uq_exchange_rate_date` (`from_currency_code`, `to_currency_code`, `effective_date`), FOREIGN KEY (`from_currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`to_currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE CASCADE ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- CRM & SALES TABLES
-- ============================================
CREATE TABLE `leads` ( `lead_id` INT AUTO_INCREMENT PRIMARY KEY, `first_name` VARCHAR(100) NULL, `last_name` VARCHAR(100) NULL, `company_name` VARCHAR(255) NULL, `email` VARCHAR(255) NULL, `phone` VARCHAR(50) NULL, `lead_source` VARCHAR(100) NULL, `lead_status_id` TINYINT UNSIGNED NOT NULL, `assigned_user_id` INT NULL COMMENT 'Responsible user for this lead', `country_id` INT NULL, `notes` TEXT NULL, `converted_company_id` INT NULL UNIQUE, `converted_tender_id` INT NULL UNIQUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`lead_status_id`) REFERENCES `lead_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`assigned_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`country_id`) REFERENCES `countries`(`country_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`converted_company_id`) REFERENCES `companies`(`company_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_lead_status` (`lead_status_id`), INDEX `idx_lead_email` (`email`), INDEX `idx_lead_company` (`company_name`), INDEX `idx_lead_assigned_user` (`assigned_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tenders` ( `tender_id` INT AUTO_INCREMENT PRIMARY KEY, `tender_name` VARCHAR(255) NOT NULL, `company_id` INT NULL, `lead_id` INT NULL, `primary_contact_id` INT NULL, `assigned_user_id` INT NULL COMMENT 'Responsible user for this tender', `tender_status_id` TINYINT UNSIGNED NOT NULL, `estimated_value` DECIMAL(15, 2) NULL, `currency_code` CHAR(3) NULL, `probability_percent` TINYINT UNSIGNED NULL, `expected_close_date` DATE NULL, `actual_close_date` DATE NULL, `description` TEXT NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`tender_status_id`) REFERENCES `tender_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`lead_id`) REFERENCES `leads`(`lead_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`assigned_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`primary_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_tender_status` (`tender_status_id`), INDEX `idx_tender_company` (`company_id`), INDEX `idx_expected_close_date` (`expected_close_date`), INDEX `idx_tender_assigned_user` (`assigned_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE `leads` ADD CONSTRAINT `fk_lead_converted_tender` FOREIGN KEY (`converted_tender_id`) REFERENCES `tenders`(`tender_id`) ON DELETE SET NULL ON UPDATE CASCADE;
CREATE TABLE `quotes_customer` ( `quote_id` INT AUTO_INCREMENT PRIMARY KEY, `quote_number` VARCHAR(50) NOT NULL UNIQUE, `company_id` INT NOT NULL, `customer_contact_id` INT NULL, `billing_address_id` INT NULL, `shipping_address_id` INT NULL, `tender_id` INT NULL, `issued_by_user_id` INT NULL COMMENT 'User who issued/is responsible for this quote', `quote_date` DATE NOT NULL, `expiry_date` DATE NULL, `quote_status_id` TINYINT UNSIGNED NOT NULL, `currency_code` CHAR(3) NOT NULL, `subtotal_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `shipping_cost` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `tax_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `total_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `terms_conditions` TEXT NULL, `notes` TEXT NULL, `related_order_id` INT NULL UNIQUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`quote_status_id`) REFERENCES `quote_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`customer_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`billing_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`shipping_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`tender_id`) REFERENCES `tenders`(`tender_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`issued_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_quote_status` (`quote_status_id`), INDEX `idx_quote_company` (`company_id`), INDEX `idx_quote_date` (`quote_date`), INDEX `idx_quote_issued_by_user` (`issued_by_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='App logic should ensure company_id has a customer role';
CREATE TABLE `quote_customer_items` ( `quote_item_id` INT AUTO_INCREMENT PRIMARY KEY, `quote_id` INT NOT NULL, `product_id` INT NOT NULL, `quantity` INT UNSIGNED NOT NULL DEFAULT 1, `unit_price_quoted` DECIMAL(12, 2) NOT NULL, `line_total` DECIMAL(15, 2) NOT NULL, `notes` VARCHAR(255) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (`quote_id`) REFERENCES `quotes_customer`(`quote_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY `uq_quote_customer_product` (`quote_id`, `product_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `orders` ( `order_id` INT AUTO_INCREMENT PRIMARY KEY, `company_id` INT NOT NULL, `related_quote_id` INT NULL UNIQUE, `customer_contact_id` INT NULL, `billing_address_id` INT NULL, `shipping_address_id` INT NULL, `created_by_user_id` INT NULL COMMENT 'User who created/is responsible for this order', `order_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, `order_status_id` TINYINT UNSIGNED NOT NULL, `currency_code` CHAR(3) NOT NULL, `subtotal_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `shipping_cost` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `tax_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `total_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `payment_method` VARCHAR(50) NULL, `payment_status_id` TINYINT UNSIGNED NOT NULL, `shipping_address_line1` VARCHAR(255) NULL, `shipping_address_line2` VARCHAR(255) NULL, `shipping_city` VARCHAR(100) NULL, `shipping_state_province` VARCHAR(100) NULL, `shipping_postal_code` VARCHAR(20) NULL, `shipping_country_id` INT NULL, `preferred_warehouse_id` INT NULL, `customer_notes` TEXT NULL, `internal_notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`order_status_id`) REFERENCES `order_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`payment_status_id`) REFERENCES `payment_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`customer_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`billing_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`shipping_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`shipping_country_id`) REFERENCES `countries`(`country_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`related_quote_id`) REFERENCES `quotes_customer`(`quote_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`preferred_warehouse_id`) REFERENCES `warehouses`(`warehouse_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_order_date` (`order_date`), INDEX `idx_order_status` (`order_status_id`), INDEX `idx_order_company` (`company_id`), INDEX `idx_order_payment_status` (`payment_status_id`), INDEX `idx_order_created_by_user` (`created_by_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='App logic should ensure company_id has a customer role';
ALTER TABLE `quotes_customer` ADD CONSTRAINT `fk_quote_related_order` FOREIGN KEY (`related_order_id`) REFERENCES `orders`(`order_id`) ON DELETE SET NULL ON UPDATE CASCADE;
CREATE TABLE `order_items` ( `order_item_id` INT AUTO_INCREMENT PRIMARY KEY, `order_id` INT NOT NULL, `product_id` INT NOT NULL, `quantity` INT UNSIGNED NOT NULL DEFAULT 1, `unit_price_at_order` DECIMAL(12, 2) NOT NULL, `line_total` DECIMAL(15, 2) NOT NULL, `notes` VARCHAR(255) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY `uq_order_product` (`order_id`, `product_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- WAREHOUSING & SHIPPING TABLES
-- ============================================
CREATE TABLE `shipments` ( `shipment_id` INT AUTO_INCREMENT PRIMARY KEY, `order_id` INT NOT NULL, `warehouse_id` INT NULL, `shipment_date` DATETIME NULL, `carrier` VARCHAR(100) NULL, `tracking_number` VARCHAR(100) NULL, `shipping_cost_actual` DECIMAL(10, 2) NULL, `shipping_cost_actual_currency_code` CHAR(3) NULL, `shipment_status_id` TINYINT UNSIGNED NOT NULL, `estimated_delivery_date` DATE NULL, `actual_delivery_date` DATE NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`shipment_status_id`) REFERENCES `shipment_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses`(`warehouse_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_tracking_number` (`tracking_number`), INDEX `idx_shipment_status` (`shipment_status_id`), INDEX `idx_shipment_order` (`order_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `shipment_items` ( `shipment_item_id` INT AUTO_INCREMENT PRIMARY KEY, `shipment_id` INT NOT NULL, `order_item_id` INT NOT NULL, `quantity_shipped` INT UNSIGNED NOT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (`shipment_id`) REFERENCES `shipments`(`shipment_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`order_item_id`) REFERENCES `order_items`(`order_item_id`) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY `uq_shipment_order_item` (`shipment_id`, `order_item_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- PROCUREMENT TABLES
-- ============================================
CREATE TABLE `quotes_supplier` (
    `supplier_quote_id` INT AUTO_INCREMENT PRIMARY KEY,
    `company_id` INT NOT NULL,
    `supplier_contact_id` INT NULL,
    `supplier_quote_ref` VARCHAR(100) NULL,
    `request_ref` VARCHAR(100) NULL,
    `recorded_by_user_id` INT NULL COMMENT 'User who recorded this supplier quote',
    `quote_received_date` DATE NOT NULL,
    `expiry_date` DATE NULL,
    `quote_status_id` TINYINT UNSIGNED NOT NULL,
    `currency_code` CHAR(3) NOT NULL,
    `total_amount` DECIMAL(15, 2) NULL,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`quote_status_id`) REFERENCES `quote_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`supplier_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`recorded_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_supplier_quote_ref` (`supplier_quote_ref`),
    INDEX `idx_supplier_quote_status` (`quote_status_id`),
    INDEX `idx_supplier_quote_company` (`company_id`),
    INDEX `idx_quote_supp_recorded_by` (`recorded_by_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='App logic should ensure company_id has a supplier role';

CREATE TABLE `quote_supplier_items` ( `supplier_quote_item_id` INT AUTO_INCREMENT PRIMARY KEY, `supplier_quote_id` INT NOT NULL, `product_id` INT NOT NULL, `supplier_sku` VARCHAR(100) NULL, `description` VARCHAR(255) NULL, `quantity` INT UNSIGNED NOT NULL, `unit_cost` DECIMAL(12, 2) NOT NULL, `line_total` DECIMAL(15, 2) NOT NULL, `lead_time_days` INT UNSIGNED NULL, `notes` VARCHAR(255) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (`supplier_quote_id`) REFERENCES `quotes_supplier`(`supplier_quote_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY `uq_quote_supplier_product` (`supplier_quote_id`, `product_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `purchase_orders` ( `po_id` INT AUTO_INCREMENT PRIMARY KEY, `po_number` VARCHAR(50) NOT NULL UNIQUE, `company_id` INT NOT NULL, `supplier_contact_id` INT NULL, `ship_from_address_id` INT NULL, `order_date` DATE NOT NULL, `expected_delivery_date` DATE NULL, `deliver_to_warehouse_id` INT NULL, `placed_by_user_id` INT NULL COMMENT 'User who placed/is responsible for this PO', `po_status_id` TINYINT UNSIGNED NOT NULL, `currency_code` CHAR(3) NOT NULL, `subtotal_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `shipping_cost` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `tax_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00, `total_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00, `payment_terms` VARCHAR(100) NULL, `shipping_method` VARCHAR(100) NULL, `notes` TEXT NULL, `related_supplier_quote_id` INT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`po_status_id`) REFERENCES `po_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`supplier_contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`ship_from_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`placed_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`related_supplier_quote_id`) REFERENCES `quotes_supplier`(`supplier_quote_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`deliver_to_warehouse_id`) REFERENCES `warehouses`(`warehouse_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_po_status` (`po_status_id`), INDEX `idx_po_company` (`company_id`), INDEX `idx_po_expected_delivery` (`expected_delivery_date`), INDEX `idx_po_placed_by_user` (`placed_by_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='App logic should ensure company_id has a supplier role';
CREATE TABLE `purchase_order_items` ( `po_item_id` INT AUTO_INCREMENT PRIMARY KEY, `po_id` INT NOT NULL, `product_id` INT NOT NULL, `quantity_ordered` INT UNSIGNED NOT NULL, `unit_cost` DECIMAL(12, 2) NOT NULL, `line_total` DECIMAL(15, 2) NOT NULL, `quantity_received` INT UNSIGNED NOT NULL DEFAULT 0, `received_date` DATETIME NULL, `notes` VARCHAR(255) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`po_id`) REFERENCES `purchase_orders`(`po_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY `uq_po_product` (`po_id`, `product_id`), INDEX `idx_po_item_received` (`quantity_received`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- BILLING & PAYMENTS TABLES
-- ============================================
CREATE TABLE `invoices_customer` (
    `invoice_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_number` VARCHAR(50) NOT NULL UNIQUE,
    `company_id` INT NOT NULL,
    `order_id` INT NOT NULL,
    `created_by_user_id` INT NULL COMMENT 'User who created/issued this customer invoice',
    `billing_address_id` INT NULL,
    `invoice_date` DATE NOT NULL,
    `due_date` DATE NULL,
    `invoice_status_id` TINYINT UNSIGNED NOT NULL,
    `currency_code` CHAR(3) NOT NULL,
    `subtotal_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `shipping_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `tax_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `total_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `amount_paid` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `balance_due` DECIMAL(15, 2) AS (`total_amount` - `amount_paid`) STORED,
    `payment_terms` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`invoice_status_id`) REFERENCES `invoice_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`billing_address_id`) REFERENCES `addresses`(`address_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_invoice_cust_status` (`invoice_status_id`),
    INDEX `idx_invoice_cust_due_date` (`due_date`),
    INDEX `idx_invoice_cust_company` (`company_id`),
    INDEX `idx_invoice_cust_created_by` (`created_by_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `invoices_supplier` (
    `supplier_invoice_id` INT AUTO_INCREMENT PRIMARY KEY,
    `company_id` INT NOT NULL,
    `po_id` INT NULL,
    `entered_by_user_id` INT NULL COMMENT 'User who entered this supplier invoice',
    `supplier_invoice_number` VARCHAR(100) NOT NULL,
    `invoice_date` DATE NOT NULL,
    `due_date` DATE NULL,
    `invoice_status_id` TINYINT UNSIGNED NOT NULL,
    `currency_code` CHAR(3) NOT NULL,
    `subtotal_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `shipping_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `tax_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `total_amount` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `amount_paid` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `balance_due` DECIMAL(15, 2) AS (`total_amount` - `amount_paid`) STORED,
    `payment_terms` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`invoice_status_id`) REFERENCES `supplier_invoice_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`po_id`) REFERENCES `purchase_orders`(`po_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`entered_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_invoice_supp_status` (`invoice_status_id`),
    INDEX `idx_invoice_supp_due_date` (`due_date`),
    INDEX `idx_invoice_supp_company` (`company_id`),
    INDEX `idx_invoice_supp_entered_by` (`entered_by_user_id`),
    UNIQUE KEY `uq_supplier_invoice_number_company` (`company_id`, `supplier_invoice_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `payments` ( `payment_id` INT AUTO_INCREMENT PRIMARY KEY, `customer_invoice_id` INT NULL, `supplier_invoice_id` INT NULL, `payment_date` DATETIME NOT NULL, `amount` DECIMAL(15, 2) NOT NULL, `currency_code` CHAR(3) NOT NULL, `payment_method` VARCHAR(50) NULL, `reference_number` VARCHAR(100) NULL, `processed_by_user_id` INT NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`customer_invoice_id`) REFERENCES `invoices_customer`(`invoice_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (`supplier_invoice_id`) REFERENCES `invoices_supplier`(`supplier_invoice_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    FOREIGN KEY (`processed_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_payment_date` (`payment_date`), CONSTRAINT `chk_payment_link` CHECK ((`customer_invoice_id` IS NOT NULL AND `supplier_invoice_id` IS NULL) OR (`customer_invoice_id` IS NULL AND `supplier_invoice_id` IS NOT NULL)) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- OTHER OPERATIONAL TABLES
-- ============================================
CREATE TABLE `serial_numbers` ( `serial_number_id` INT AUTO_INCREMENT PRIMARY KEY, `product_id` INT NOT NULL, `serial_number` VARCHAR(100) NOT NULL, `status_id` TINYINT UNSIGNED NOT NULL, `current_stock_level_id` INT NULL, `po_item_id_received` INT NULL, `shipment_item_id_shipped` INT NULL, `rma_item_id_returned` INT NULL, `received_date` DATETIME NULL, `shipped_date` DATETIME NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE KEY `uq_product_serial` (`product_id`, `serial_number`), FOREIGN KEY (`status_id`) REFERENCES `serial_number_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`current_stock_level_id`) REFERENCES `stock_levels`(`stock_level_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`po_item_id_received`) REFERENCES `purchase_order_items`(`po_item_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`shipment_item_id_shipped`) REFERENCES `shipment_items`(`shipment_item_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_serial_status` (`status_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `rmas` ( `rma_id` INT AUTO_INCREMENT PRIMARY KEY, `rma_number` VARCHAR(50) NOT NULL UNIQUE, `company_id` INT NOT NULL, `order_id` INT NULL, `rma_reason` VARCHAR(255) NULL, `rma_status_id` TINYINT UNSIGNED NOT NULL, `requested_date` DATE NOT NULL, `approved_by_user_id` INT NULL, `notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`rma_status_id`) REFERENCES `rma_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`approved_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_rma_status` (`rma_status_id`), INDEX `idx_rma_company` (`company_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `rma_items` ( `rma_item_id` INT AUTO_INCREMENT PRIMARY KEY, `rma_id` INT NOT NULL, `order_item_id` INT NULL, `product_id` INT NOT NULL, `serial_number_id` INT NULL UNIQUE, `quantity_returned` INT UNSIGNED NOT NULL, `condition_id` TINYINT UNSIGNED NULL, `action_requested_id` TINYINT UNSIGNED NULL, `action_taken_id` TINYINT UNSIGNED NULL, `notes` VARCHAR(255) NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (`rma_id`) REFERENCES `rmas`(`rma_id`) ON DELETE CASCADE ON UPDATE CASCADE, FOREIGN KEY (`order_item_id`) REFERENCES `order_items`(`order_item_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`serial_number_id`) REFERENCES `serial_numbers`(`serial_number_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`condition_id`) REFERENCES `rma_item_conditions`(`condition_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`action_requested_id`) REFERENCES `rma_item_actions`(`action_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`action_taken_id`) REFERENCES `rma_item_actions`(`action_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_rma_item_rma` (`rma_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE `serial_numbers` ADD CONSTRAINT `fk_serial_rma_item` FOREIGN KEY (`rma_item_id_returned`) REFERENCES `rma_items`(`rma_item_id`) ON DELETE SET NULL ON UPDATE CASCADE;
CREATE TABLE `support_tickets` ( `ticket_id` INT AUTO_INCREMENT PRIMARY KEY, `ticket_number` VARCHAR(50) NOT NULL UNIQUE, `company_id` INT NOT NULL, `contact_id` INT NULL, `subject` VARCHAR(255) NOT NULL, `description` TEXT NOT NULL, `ticket_status_id` TINYINT UNSIGNED NOT NULL, `priority_id` TINYINT UNSIGNED NOT NULL, `source` VARCHAR(50) NULL, `assigned_user_id` INT NULL, `related_order_id` INT NULL, `related_product_id` INT NULL, `related_rma_id` INT NULL, `resolution` TEXT NULL, `internal_notes` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `closed_at` DATETIME NULL, FOREIGN KEY (`ticket_status_id`) REFERENCES `ticket_statuses`(`status_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`priority_id`) REFERENCES `ticket_priorities`(`priority_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`company_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`assigned_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`related_order_id`) REFERENCES `orders`(`order_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`related_product_id`) REFERENCES `products`(`product_id`) ON DELETE SET NULL ON UPDATE CASCADE, FOREIGN KEY (`related_rma_id`) REFERENCES `rmas`(`rma_id`) ON DELETE SET NULL ON UPDATE CASCADE, INDEX `idx_ticket_status` (`ticket_status_id`), INDEX `idx_ticket_priority` (`priority_id`), INDEX `idx_ticket_company` (`company_id`), INDEX `idx_ticket_contact` (`contact_id`), INDEX `idx_ticket_assignee` (`assigned_user_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `attachments` ( `attachment_id` INT AUTO_INCREMENT PRIMARY KEY, `file_name` VARCHAR(255) NOT NULL, `file_path` VARCHAR(512) NOT NULL, `file_type` VARCHAR(100) NULL, `file_size_bytes` BIGINT UNSIGNED NULL, `uploaded_by_user_id` INT NULL, `description` TEXT NULL, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (`uploaded_by_user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `lead_attachments` ( `lead_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`lead_id`, `attachment_id`), FOREIGN KEY (`lead_id`) REFERENCES `leads`(`lead_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tender_attachments` ( `tender_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`tender_id`, `attachment_id`), FOREIGN KEY (`tender_id`) REFERENCES `tenders`(`tender_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `quote_customer_attachments` ( `quote_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`quote_id`, `attachment_id`), FOREIGN KEY (`quote_id`) REFERENCES `quotes_customer`(`quote_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `purchase_order_attachments` ( `po_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`po_id`, `attachment_id`), FOREIGN KEY (`po_id`) REFERENCES `purchase_orders`(`po_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `invoice_customer_attachments` ( `invoice_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`invoice_id`, `attachment_id`), FOREIGN KEY (`invoice_id`) REFERENCES `invoices_customer`(`invoice_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `invoice_supplier_attachments` ( `supplier_invoice_id` INT NOT NULL, `attachment_id` INT NOT NULL, PRIMARY KEY (`supplier_invoice_id`, `attachment_id`), FOREIGN KEY (`supplier_invoice_id`) REFERENCES `invoices_supplier`(`supplier_invoice_id`) ON DELETE CASCADE, FOREIGN KEY (`attachment_id`) REFERENCES `attachments`(`attachment_id`) ON DELETE CASCADE ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- DATABASE TRIGGERS FOR ROBUSTNESS
-- ============================================

DELIMITER $$

-- --- Triggers for Address Consistency ---

CREATE TRIGGER `addr_consistency_before_insert`
BEFORE INSERT ON `addresses`
FOR EACH ROW
BEGIN
    DECLARE dept_company_id INT;
    IF NEW.owner_department_id IS NOT NULL THEN
        SELECT company_id INTO dept_company_id FROM departments WHERE department_id = NEW.owner_department_id;
        IF dept_company_id IS NULL OR dept_company_id != NEW.company_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Address consistency error: Department does not belong to the specified Company.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `addr_consistency_before_update`
BEFORE UPDATE ON `addresses`
FOR EACH ROW
BEGIN
    DECLARE dept_company_id INT;
    IF NEW.owner_department_id IS NOT NULL AND (NEW.owner_department_id != OLD.owner_department_id OR NEW.company_id != OLD.company_id OR OLD.owner_department_id IS NULL) THEN
        SELECT company_id INTO dept_company_id FROM departments WHERE department_id = NEW.owner_department_id;
        IF dept_company_id IS NULL OR dept_company_id != NEW.company_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Address consistency error: Updated Department does not belong to the specified Company.';
        END IF;
    END IF;
END$$

-- --- Triggers for Single Primary Address ---

CREATE TRIGGER `addr_enforce_single_primary_insert`
BEFORE INSERT ON `addresses`
FOR EACH ROW
BEGIN
    DECLARE existing_primary_billing INT DEFAULT 0;
    DECLARE existing_primary_shipping INT DEFAULT 0;

    IF NEW.is_primary_billing_for_owner = TRUE THEN
        IF NEW.owner_department_id IS NULL THEN
            SELECT COUNT(*) INTO existing_primary_billing FROM addresses
            WHERE company_id = NEW.company_id AND owner_department_id IS NULL AND is_primary_billing_for_owner = TRUE AND is_deleted = FALSE;
        ELSE
            SELECT COUNT(*) INTO existing_primary_billing FROM addresses
            WHERE owner_department_id = NEW.owner_department_id AND is_primary_billing_for_owner = TRUE AND is_deleted = FALSE;
        END IF;

        IF existing_primary_billing > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot set as primary billing: Another primary billing address already exists for this owner.';
        END IF;
    END IF;

    IF NEW.is_primary_shipping_for_owner = TRUE THEN
        IF NEW.owner_department_id IS NULL THEN
            SELECT COUNT(*) INTO existing_primary_shipping FROM addresses
            WHERE company_id = NEW.company_id AND owner_department_id IS NULL AND is_primary_shipping_for_owner = TRUE AND is_deleted = FALSE;
        ELSE
            SELECT COUNT(*) INTO existing_primary_shipping FROM addresses
            WHERE owner_department_id = NEW.owner_department_id AND is_primary_shipping_for_owner = TRUE AND is_deleted = FALSE;
        END IF;

        IF existing_primary_shipping > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot set as primary shipping: Another primary shipping address already exists for this owner.';
        END IF;
    END IF;
END$$


CREATE TRIGGER `addr_enforce_single_primary_update`
BEFORE UPDATE ON `addresses`
FOR EACH ROW
BEGIN
    DECLARE existing_primary_billing INT DEFAULT 0;
    DECLARE existing_primary_shipping INT DEFAULT 0;

    IF NEW.is_primary_billing_for_owner = TRUE AND (OLD.is_primary_billing_for_owner = FALSE OR OLD.is_primary_billing_for_owner IS NULL) THEN
        IF NEW.owner_department_id IS NULL THEN
            SELECT COUNT(*) INTO existing_primary_billing FROM addresses
            WHERE company_id = NEW.company_id AND owner_department_id IS NULL AND is_primary_billing_for_owner = TRUE AND address_id != NEW.address_id AND is_deleted = FALSE;
        ELSE
            SELECT COUNT(*) INTO existing_primary_billing FROM addresses
            WHERE owner_department_id = NEW.owner_department_id AND is_primary_billing_for_owner = TRUE AND address_id != NEW.address_id AND is_deleted = FALSE;
        END IF;

        IF existing_primary_billing > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update to primary billing: Another primary billing address already exists for this owner.';
        END IF;
    END IF;

    IF NEW.is_primary_shipping_for_owner = TRUE AND (OLD.is_primary_shipping_for_owner = FALSE OR OLD.is_primary_shipping_for_owner IS NULL) THEN
        IF NEW.owner_department_id IS NULL THEN
            SELECT COUNT(*) INTO existing_primary_shipping FROM addresses
            WHERE company_id = NEW.company_id AND owner_department_id IS NULL AND is_primary_shipping_for_owner = TRUE AND address_id != NEW.address_id AND is_deleted = FALSE;
        ELSE
            SELECT COUNT(*) INTO existing_primary_shipping FROM addresses
            WHERE owner_department_id = NEW.owner_department_id AND is_primary_shipping_for_owner = TRUE AND address_id != NEW.address_id AND is_deleted = FALSE;
        END IF;

        IF existing_primary_shipping > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update to primary shipping: Another primary shipping address already exists for this owner.';
        END IF;
    END IF;
END$$


-- --- Triggers for Single Primary Contact per Role Link ---

CREATE TRIGGER `cust_contact_single_primary_insert`
BEFORE INSERT ON `customer_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_customer = TRUE THEN
        SELECT COUNT(*) INTO existing_primary FROM customer_contacts
        WHERE customer_id = NEW.customer_id AND is_primary_for_customer = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add primary contact: Another primary contact already exists for this customer role.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `cust_contact_single_primary_update`
BEFORE UPDATE ON `customer_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_customer = TRUE AND (OLD.is_primary_for_customer = FALSE OR OLD.is_primary_for_customer IS NULL) THEN
        SELECT COUNT(*) INTO existing_primary FROM customer_contacts
        WHERE customer_id = NEW.customer_id AND contact_id != NEW.contact_id AND is_primary_for_customer = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update to primary contact: Another primary contact already exists for this customer role.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `supp_contact_single_primary_insert`
BEFORE INSERT ON `supplier_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_supplier = TRUE THEN
        SELECT COUNT(*) INTO existing_primary FROM supplier_contacts
        WHERE supplier_id = NEW.supplier_id AND is_primary_for_supplier = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add primary contact: Another primary contact already exists for this supplier role.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `supp_contact_single_primary_update`
BEFORE UPDATE ON `supplier_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_supplier = TRUE AND (OLD.is_primary_for_supplier = FALSE OR OLD.is_primary_for_supplier IS NULL) THEN
        SELECT COUNT(*) INTO existing_primary FROM supplier_contacts
        WHERE supplier_id = NEW.supplier_id AND contact_id != NEW.contact_id AND is_primary_for_supplier = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update to primary contact: Another primary contact already exists for this supplier role.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `part_contact_single_primary_insert`
BEFORE INSERT ON `partner_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_partner = TRUE THEN
        SELECT COUNT(*) INTO existing_primary FROM partner_contacts
        WHERE partner_id = NEW.partner_id AND is_primary_for_partner = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add primary contact: Another primary contact already exists for this partner role.';
        END IF;
    END IF;
END$$

CREATE TRIGGER `part_contact_single_primary_update`
BEFORE UPDATE ON `partner_contacts`
FOR EACH ROW
BEGIN
    DECLARE existing_primary INT DEFAULT 0;
    IF NEW.is_primary_for_partner = TRUE AND (OLD.is_primary_for_partner = FALSE OR OLD.is_primary_for_partner IS NULL) THEN
        SELECT COUNT(*) INTO existing_primary FROM partner_contacts
        WHERE partner_id = NEW.partner_id AND contact_id != NEW.contact_id AND is_primary_for_partner = TRUE;
        IF existing_primary > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update to primary contact: Another primary contact already exists for this partner role.';
        END IF;
    END IF;
END$$


DELIMITER ;

-- ============================================
-- ADDING REMAINING FOREIGN KEY CONSTRAINTS
-- ============================================
ALTER TABLE `companies` ADD CONSTRAINT `fk_company_pref_currency` FOREIGN KEY (`preferred_currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `products` ADD CONSTRAINT `fk_product_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `products` ADD CONSTRAINT `fk_product_cost_currency` FOREIGN KEY (`default_cost_currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `tenders` ADD CONSTRAINT `fk_tender_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `quotes_customer` ADD CONSTRAINT `fk_quote_cust_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `orders` ADD CONSTRAINT `fk_order_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `shipments` ADD CONSTRAINT `fk_shipment_cost_currency` FOREIGN KEY (`shipping_cost_actual_currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `quotes_supplier` ADD CONSTRAINT `fk_quote_supp_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `purchase_orders` ADD CONSTRAINT `fk_po_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `invoices_customer` ADD CONSTRAINT `fk_invoice_cust_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `invoices_supplier` ADD CONSTRAINT `fk_invoice_supp_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payment_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies`(`currency_code`) ON DELETE RESTRICT ON UPDATE CASCADE;


-- ============================================
-- DATA POPULATION & SETTING DEFAULTS
-- (Sample data for a new installation)
-- ============================================
INSERT INTO `currencies` (`currency_code`, `currency_name`, `symbol`) VALUES ('USD', 'US Dollar', '$'), ('EUR', 'Euro', '€'), ('GBP', 'British Pound', '£'); SET @currency_usd = 'USD';
INSERT INTO `countries` (`country_name`, `country_code_iso2`) VALUES ('United States', 'US'), ('United Kingdom', 'GB'), ('Germany', 'DE'); SET @us_country_id = (SELECT country_id FROM countries WHERE country_code_iso2 = 'US'); SET @gb_country_id = (SELECT country_id FROM countries WHERE country_code_iso2 = 'GB'); SET @de_country_id = (SELECT country_id FROM countries WHERE country_code_iso2 = 'DE');
INSERT INTO `customer_account_statuses` (`status_name`) VALUES ('Active'), ('Inactive'), ('Pending'); SET @cust_status_active_id = (SELECT status_id FROM customer_account_statuses WHERE status_name = 'Active');
INSERT INTO `lead_statuses` (`status_name`) VALUES ('New'), ('Contacted'), ('Qualified'), ('Converted'); SET @lead_status_new_id = (SELECT status_id FROM lead_statuses WHERE status_name = 'New');
INSERT INTO `tender_statuses` (`status_name`) VALUES ('Qualification'), ('Proposal'), ('Closed Won'), ('Closed Lost'); SET @tender_status_qual_id = (SELECT status_id FROM tender_statuses WHERE status_name = 'Qualification');
INSERT INTO `quote_statuses` (`status_name`) VALUES ('Draft'), ('Sent'), ('Accepted'), ('Rejected'), ('Received'); SET @quote_status_draft_id = (SELECT status_id FROM quote_statuses WHERE status_name = 'Draft'); SET @quote_supp_status_received_id = (SELECT status_id FROM quote_statuses WHERE status_name = 'Received');
INSERT INTO `order_statuses` (`status_name`) VALUES ('Pending'), ('Processing'), ('Shipped Complete'), ('Cancelled'); SET @order_status_pending_id = (SELECT status_id FROM order_statuses WHERE status_name = 'Pending'); SET @order_status_processing_id = (SELECT status_id FROM order_statuses WHERE status_name = 'Processing');
INSERT INTO `payment_statuses` (`status_name`) VALUES ('Unpaid'), ('Paid'); SET @payment_status_unpaid_id = (SELECT status_id FROM payment_statuses WHERE status_name = 'Unpaid');
INSERT INTO `shipment_statuses` (`status_name`) VALUES ('Preparing'), ('Shipped'), ('Delivered'); SET @shipment_status_preparing_id = (SELECT status_id FROM shipment_statuses WHERE status_name = 'Preparing');
INSERT INTO `po_statuses` (`status_name`) VALUES ('Draft'), ('Sent'), ('Fully Received'), ('Cancelled'); SET @po_status_draft_id = (SELECT status_id FROM po_statuses WHERE status_name = 'Draft'); SET @po_status_sent_id = (SELECT status_id FROM po_statuses WHERE status_name = 'Sent');
INSERT INTO `invoice_statuses` (`status_name`) VALUES ('Draft'), ('Sent'), ('Paid'), ('Void'); SET @invoice_status_draft_id = (SELECT status_id FROM invoice_statuses WHERE status_name = 'Draft'); SET @invoice_status_paid_id = (SELECT status_id FROM invoice_statuses WHERE status_name = 'Paid'); SET @invoice_status_void_id = (SELECT status_id FROM invoice_statuses WHERE status_name = 'Void');
INSERT INTO `supplier_invoice_statuses` (`status_name`) VALUES ('Received'), ('Approved'), ('Paid'), ('Disputed'); SET @supp_invoice_status_received_id = (SELECT status_id FROM supplier_invoice_statuses WHERE status_name = 'Received'); SET @supp_invoice_status_paid_id = (SELECT status_id FROM supplier_invoice_statuses WHERE status_name = 'Paid');
INSERT INTO `serial_number_statuses` (`status_name`) VALUES ('In Stock'), ('Allocated'), ('Shipped'), ('Returned'), ('Scrapped'); SET @sn_status_instock_id = (SELECT status_id FROM serial_number_statuses WHERE status_name = 'In Stock');
INSERT INTO `rma_statuses` (`status_name`) VALUES ('Requested'), ('Approved'), ('Received'), ('Completed'); SET @rma_status_requested_id = (SELECT status_id FROM rma_statuses WHERE status_name = 'Requested');
INSERT INTO `rma_item_conditions` (`condition_name`) VALUES ('New'), ('Used'), ('Damaged'), ('Defective'); SET @rma_cond_new_id = (SELECT condition_id FROM rma_item_conditions WHERE condition_name = 'New');
INSERT INTO `rma_item_actions` (`action_name`) VALUES ('Refund'), ('Replacement'), ('Repair'), ('Credit'), ('Scrapped'); SET @rma_action_refund_id = (SELECT action_id FROM rma_item_actions WHERE action_name = 'Refund');
INSERT INTO `ticket_statuses` (`status_name`) VALUES ('Open'), ('In Progress'), ('Resolved'), ('Closed'); SET @ticket_status_open_id = (SELECT status_id FROM ticket_statuses WHERE status_name = 'Open');
INSERT INTO `ticket_priorities` (`priority_name`, `level`) VALUES ('Low', 10), ('Medium', 20), ('High', 30); SET @ticket_priority_medium_id = (SELECT priority_id FROM ticket_priorities WHERE priority_name = 'Medium'); SET @ticket_priority_high_id = (SELECT priority_id FROM ticket_priorities WHERE priority_name = 'High');
INSERT INTO `market_segments` (`segment_name`) VALUES ('Enterprise'), ('SMB'), ('Government'), ('Manufacturing'); SET @seg_enterprise_id = (SELECT segment_id FROM market_segments WHERE segment_name='Enterprise'); SET @seg_smb_id = (SELECT segment_id FROM market_segments WHERE segment_name='SMB'); SET @seg_gov_id = (SELECT segment_id FROM market_segments WHERE segment_name='Government'); SET @seg_mfg_id = (SELECT segment_id FROM market_segments WHERE segment_name='Manufacturing');
INSERT INTO `expertise_tags` (`tag_name`) VALUES ('Technical Support'), ('Billing Inquiry'), ('Sales Inquiry'); SET @exp_tech_id = (SELECT tag_id FROM expertise_tags WHERE tag_name='Technical Support'); SET @exp_billing_id = (SELECT tag_id FROM expertise_tags WHERE tag_name='Billing Inquiry'); SET @exp_sales_id = (SELECT tag_id FROM expertise_tags WHERE tag_name='Sales Inquiry');
INSERT INTO `product_categories` (`category_name`) VALUES ('IoT Gateways'), ('IoT Sensors'), ('Accessories'); SET @cat_gateway_id = (SELECT category_id FROM product_categories WHERE category_name='IoT Gateways'); SET @cat_sensor_id = (SELECT category_id FROM product_categories WHERE category_name='IoT Sensors'); SET @cat_accessory_id = (SELECT category_id FROM product_categories WHERE category_name='Accessories');
INSERT INTO `users` (`first_name`, `last_name`, `email`, `password_hash`) VALUES ('Admin', 'User', 'admin@example.com', 'hash1'), ('Sales', 'Rep', 'sales@example.com', 'hash2'), ('Support', 'Tech', 'support@example.com', 'hash3'); SET @admin_user_id = (SELECT user_id FROM users WHERE email='admin@example.com'); SET @sales_user_id = (SELECT user_id FROM users WHERE email='sales@example.com'); SET @support_user_id = (SELECT user_id FROM users WHERE email='support@example.com');
INSERT INTO `roles` (`role_name`) VALUES ('Administrator'), ('Sales'), ('Support'); SET @admin_role_id = (SELECT role_id FROM roles WHERE role_name='Administrator'); SET @sales_role_id = (SELECT role_id FROM roles WHERE role_name='Sales'); SET @support_role_id = (SELECT role_id FROM roles WHERE role_name='Support');
INSERT INTO `permissions` (`permission_name`) VALUES ('manage_all'), ('manage_sales'), ('manage_support');
SET @perm_manage_all_id = LAST_INSERT_ID();
SET @perm_manage_sales_id = LAST_INSERT_ID() + 1;
SET @perm_manage_support_id = LAST_INSERT_ID() + 2;

INSERT INTO `role_permissions` (`role_id`, `permission_id`) VALUES (@admin_role_id, @perm_manage_all_id), (@sales_role_id, @perm_manage_sales_id), (@support_role_id, @perm_manage_support_id);
INSERT INTO `partner_types` (`type_name`) VALUES ('Reseller'), ('Technology');
SET @pt_reseller_id = LAST_INSERT_ID();
SET @pt_tech_id = LAST_INSERT_ID() + 1;


SET @sql = CONCAT('ALTER TABLE `customers` ALTER COLUMN `account_status_id` SET DEFAULT ', @cust_status_active_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `leads` ALTER COLUMN `lead_status_id` SET DEFAULT ', @lead_status_new_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `tenders` ALTER COLUMN `tender_status_id` SET DEFAULT ', @tender_status_qual_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `quotes_customer` ALTER COLUMN `quote_status_id` SET DEFAULT ', @quote_status_draft_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `orders` ALTER COLUMN `order_status_id` SET DEFAULT ', @order_status_pending_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `orders` ALTER COLUMN `payment_status_id` SET DEFAULT ', @payment_status_unpaid_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `shipments` ALTER COLUMN `shipment_status_id` SET DEFAULT ', @shipment_status_preparing_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `quotes_supplier` ALTER COLUMN `quote_status_id` SET DEFAULT ', @quote_supp_status_received_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `purchase_orders` ALTER COLUMN `po_status_id` SET DEFAULT ', @po_status_draft_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `invoices_customer` ALTER COLUMN `invoice_status_id` SET DEFAULT ', @invoice_status_draft_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `invoices_supplier` ALTER COLUMN `invoice_status_id` SET DEFAULT ', @supp_invoice_status_received_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `serial_numbers` ALTER COLUMN `status_id` SET DEFAULT ', @sn_status_instock_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `rmas` ALTER COLUMN `rma_status_id` SET DEFAULT ', @rma_status_requested_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `support_tickets` ALTER COLUMN `ticket_status_id` SET DEFAULT ', @ticket_status_open_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `support_tickets` ALTER COLUMN `priority_id` SET DEFAULT ', @ticket_priority_medium_id, ';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('ALTER TABLE `products` ALTER COLUMN `currency_code` SET DEFAULT ''', @currency_usd, ''';'); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- Populate Core Data
INSERT INTO `companies` (`company_name`, `vat_number`, `preferred_currency_code`) VALUES ('Example Corp', 'GB123456789', @currency_usd); SET @comp_ex_id = LAST_INSERT_ID();
INSERT INTO `companies` (`company_name`, `website`, `preferred_currency_code`) VALUES ('Component Kings Inc.', 'http://ck.example.com', @currency_usd); SET @comp_ck_id = LAST_INSERT_ID();
INSERT INTO `companies` (`company_name`) VALUES ('Partner Co'); SET @comp_part_id = LAST_INSERT_ID();

INSERT INTO `departments` (`company_id`, `department_name`) VALUES (@comp_ex_id, 'Main Office'); SET @dept_ex_main_id = LAST_INSERT_ID();
INSERT INTO `departments` (`company_id`, `department_name`) VALUES (@comp_ck_id, 'HQ'); SET @dept_ck_hq_id = LAST_INSERT_ID();
INSERT INTO `departments` (`company_id`, `department_name`) VALUES (@comp_part_id, 'General'); SET @dept_part_gen_id = LAST_INSERT_ID();
INSERT INTO `departments` (`company_id`, `department_name`, `parent_department_id`) VALUES (@comp_ex_id, 'Accounts', @dept_ex_main_id); SET @dept_ex_acct_id = LAST_INSERT_ID();
INSERT INTO `departments` (`company_id`, `department_name`, `parent_department_id`) VALUES (@comp_ck_id, 'Sales', @dept_ck_hq_id); SET @dept_ck_sales_id = LAST_INSERT_ID();


INSERT INTO `addresses` (`company_id`, `owner_department_id`, `address_type`, `address_name`, `is_primary_billing_for_owner`, `is_primary_shipping_for_owner`, `address_line1`, `city`, `postal_code`, `country_id`) VALUES
(@comp_ex_id, @dept_ex_main_id, 'Office', 'HQ Address', FALSE, FALSE, '1 Corporate Drive', 'Metropolis', '10001', @us_country_id),
(@comp_ex_id, @dept_ex_acct_id, 'Billing', 'Accounts Payable Address', TRUE, FALSE, 'PO Box 123', 'Metropolis', '10002', @us_country_id),
(@comp_ex_id, @dept_ex_main_id, 'Shipping', 'Main Receiving Dock', FALSE, TRUE, '45 Industrial Way', 'Metropolis', '10003', @us_country_id);
SET @addr_ex_hq_id = LAST_INSERT_ID();
SET @addr_ex_bill_id = LAST_INSERT_ID() + 1;
SET @addr_ex_ship_id = LAST_INSERT_ID() + 2;


INSERT INTO `addresses` (`company_id`, `owner_department_id`, `address_type`, `address_name`, `is_primary_billing_for_owner`, `is_primary_shipping_for_owner`, `address_line1`, `city`, `state_province`, `postal_code`, `country_id`) VALUES
(@comp_ck_id, @dept_ck_sales_id, 'Office', 'Sales Office', FALSE, FALSE, '100 Supply St', 'Componentville', 'CA', '90210', @us_country_id),
(@comp_ck_id, @dept_ck_hq_id, 'Shipping', 'Main Warehouse', FALSE, TRUE, '200 Distribution Dr', 'Componentville', 'CA', '90211', @us_country_id),
(@comp_ck_id, @dept_ck_hq_id, 'Billing', 'Finance Address', TRUE, FALSE, '300 Finance Ave', 'Componentville', 'CA', '90212', @us_country_id);
SET @addr_ck_sales_id = LAST_INSERT_ID();
SET @addr_ck_wh_id = LAST_INSERT_ID() + 1;
SET @addr_ck_fin_id = LAST_INSERT_ID() + 2;

INSERT INTO `addresses` (`company_id`, `owner_department_id`, `address_type`, `address_name`, `address_line1`, `city`, `country_id`) VALUES
(@comp_part_id, NULL, 'Office', 'Partner Office', '1 Partner Plaza', 'Partner City', @us_country_id);
SET @addr_part_office_id = LAST_INSERT_ID();

INSERT INTO `contacts` (`first_name`, `last_name`, `job_title`, `email`, `phone_work`, `address_id`) VALUES
('Alice', 'Smith', 'Purchasing Manager', 'alice@example.com', '555-1111', @addr_ex_hq_id),
('Bob', 'Johnson', 'Warehouse Manager', 'bob@example.com', '555-2222', @addr_ex_ship_id),
('Charlie', 'Davis', 'AP Clerk', 'charlie@example.com', '555-3333', @addr_ex_bill_id),
('David', 'Lee', 'Account Manager', 'david@ck.example.com', '666-1111', @addr_ck_sales_id),
('Eva', 'Martinez', 'AR Specialist', 'eva@ck.example.com', '666-2222', @addr_ck_fin_id),
('Frank', 'Wright', 'Partner Manager', 'frank@partner.example.com', '777-1111', @addr_part_office_id);
SET @contact_alice_id = (SELECT contact_id FROM contacts WHERE email='alice@example.com'); SET @contact_bob_id = (SELECT contact_id FROM contacts WHERE email='bob@example.com'); SET @contact_charlie_id = (SELECT contact_id FROM contacts WHERE email='charlie@example.com'); SET @contact_david_id = (SELECT contact_id FROM contacts WHERE email='david@ck.example.com'); SET @contact_eva_id = (SELECT contact_id FROM contacts WHERE email='eva@ck.example.com'); SET @contact_frank_id = (SELECT contact_id FROM contacts WHERE email='frank@partner.example.com');

UPDATE `departments` SET `default_contact_id` = @contact_alice_id WHERE `department_id` = @dept_ex_main_id;
UPDATE `departments` SET `default_contact_id` = @contact_david_id WHERE `department_id` = @dept_ck_sales_id;

INSERT INTO `department_contacts` (`department_id`, `contact_id`) VALUES (@dept_ex_main_id, @contact_alice_id), (@dept_ex_main_id, @contact_bob_id), (@dept_ex_acct_id, @contact_charlie_id), (@dept_ck_sales_id, @contact_david_id), (@dept_ck_hq_id, @contact_eva_id);
INSERT INTO `company_contacts` (`company_id`, `contact_id`) VALUES (@comp_ex_id, @contact_alice_id), (@comp_part_id, @contact_frank_id);

INSERT INTO `customers` (`company_id`, `account_manager_id`, `account_status_id`) VALUES (@comp_ex_id, @sales_user_id, @cust_status_active_id); SET @cust_ex_role_id = LAST_INSERT_ID();
INSERT INTO `suppliers` (`company_id`) VALUES (@comp_ck_id); SET @supp_ck_role_id = LAST_INSERT_ID();
INSERT INTO `partners` (`company_id`, `partner_type_id`) VALUES (@comp_part_id, @pt_tech_id); SET @part_p_role_id = LAST_INSERT_ID();

INSERT INTO `customer_contacts` (`customer_id`, `contact_id`, `is_primary_for_customer`) VALUES (@cust_ex_role_id, @contact_alice_id, TRUE);
INSERT INTO `supplier_contacts` (`supplier_id`, `contact_id`, `is_primary_for_supplier`) VALUES (@supp_ck_role_id, @contact_david_id, TRUE);
INSERT INTO `partner_contacts` (`partner_id`, `contact_id`, `is_primary_for_partner`) VALUES (@part_p_role_id, @contact_frank_id, TRUE);

INSERT INTO `company_market_segments` (`company_id`, `segment_id`) VALUES (@comp_ex_id, @seg_enterprise_id), (@comp_ex_id, @seg_gov_id), (@comp_ck_id, @seg_mfg_id);
INSERT INTO `contact_expertise` (`contact_id`, `tag_id`) VALUES (@contact_alice_id, @exp_sales_id), (@contact_charlie_id, @exp_billing_id), (@contact_david_id, @exp_sales_id), (@contact_eva_id, @exp_billing_id);

INSERT INTO `products` (`sku`, `product_name`, `category_id`, `unit_price`, `default_cost_price`, `track_serial_number`) VALUES ('GW-001', 'Gateway', @cat_gateway_id, 1200.00, 750.00, TRUE), ('SEN-TEMP-01', 'Temp Sensor', @cat_sensor_id, 75.50, 40.00, FALSE); SET @prod_gw001_id = LAST_INSERT_ID() - 1; SET @prod_sentemp01_id = LAST_INSERT_ID();
INSERT INTO `warehouses` (`warehouse_name`, `country_id`) VALUES ('Main WH', @us_country_id); SET @wh_main_id = LAST_INSERT_ID();
INSERT INTO `stock_levels` (`product_id`, `warehouse_id`, `quantity_on_hand`) VALUES (@prod_gw001_id, @wh_main_id, 25), (@prod_sentemp01_id, @wh_main_id, 200);

INSERT INTO `orders` ( `company_id`, `customer_contact_id`, `billing_address_id`, `shipping_address_id`, `created_by_user_id`, `order_status_id`, `currency_code`, `payment_status_id`, `subtotal_amount`, `shipping_cost`, `total_amount` ) VALUES (@comp_ex_id, @contact_alice_id, @addr_ex_bill_id, @addr_ex_ship_id, @sales_user_id, @order_status_processing_id, @currency_usd, @payment_status_unpaid_id, 1275.50, 25.00, 1300.50); SET @last_order_id = LAST_INSERT_ID();
INSERT INTO `order_items` (`order_id`, `product_id`, `quantity`, `unit_price_at_order`, `line_total`) VALUES (@last_order_id, @prod_gw001_id, 1, 1200.00, 1200.00), (@last_order_id, @prod_sentemp01_id, 1, 75.50, 75.50);

INSERT INTO `invoices_customer` (`invoice_number`, `company_id`, `order_id`, `created_by_user_id`, `billing_address_id`, `invoice_date`, `due_date`, `invoice_status_id`, `currency_code`, `subtotal_amount`, `shipping_amount`, `tax_amount`, `total_amount`)
VALUES ('INV-001', @comp_ex_id, @last_order_id, @sales_user_id, @addr_ex_bill_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), @invoice_status_draft_id, @currency_usd, 1275.50, 25.00, 0.00, 1300.50);
SET @last_invoice_cust_id = LAST_INSERT_ID();

INSERT INTO `purchase_orders` ( `po_number`, `company_id`, `supplier_contact_id`, `ship_from_address_id`, `order_date`, `deliver_to_warehouse_id`, `placed_by_user_id`, `po_status_id`, `currency_code`, `subtotal_amount`, `total_amount` ) VALUES ('PO-001', @comp_ck_id, @contact_david_id, @addr_ck_wh_id, CURDATE(), @wh_main_id, @admin_user_id, @po_status_sent_id, @currency_usd, 4750.00, 4750.00 ); SET @last_po_id = LAST_INSERT_ID();
INSERT INTO `purchase_order_items` (`po_id`, `product_id`, `quantity_ordered`, `unit_cost`, `line_total`) VALUES (@last_po_id, @prod_gw001_id, 5, 750.00, 3750.00);

INSERT INTO `invoices_supplier` (`company_id`, `po_id`, `entered_by_user_id`, `supplier_invoice_number`, `invoice_date`, `due_date`, `invoice_status_id`, `currency_code`, `subtotal_amount`, `total_amount`)
VALUES (@comp_ck_id, @last_po_id, @admin_user_id, 'SUPP-INV-987', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), @supp_invoice_status_received_id, @currency_usd, 4750.00, 4750.00);
SET @last_invoice_supp_id = LAST_INSERT_ID();


INSERT INTO `support_tickets` ( `ticket_number`, `company_id`, `contact_id`, `subject`, `description`, `ticket_status_id`, `priority_id`, `assigned_user_id`, `related_product_id` ) VALUES ('TKT-001', @comp_ex_id, @contact_bob_id, 'Sensor Issue', 'Temp sensor reading high', @ticket_status_open_id, @ticket_priority_high_id, @support_user_id, @prod_sentemp01_id );

INSERT INTO `exchange_rates` (`from_currency_code`, `to_currency_code`, `rate`, `effective_date`) VALUES ('EUR', 'USD', 1.08500000, '2024-01-01'), ('USD', 'EUR', 0.92165899, '2024-01-01');


-- ============================================
-- REPORTING VIEWS
-- ============================================
CREATE OR REPLACE VIEW `view_active_users` AS SELECT u.* FROM `users` u WHERE u.is_deleted = FALSE;
CREATE OR REPLACE VIEW `view_active_companies` AS SELECT c.* FROM `companies` c WHERE c.is_deleted = FALSE;
CREATE OR REPLACE VIEW `view_active_departments` AS SELECT d.* FROM `departments` d JOIN view_active_companies c ON d.company_id = c.company_id WHERE d.is_deleted = FALSE;
CREATE OR REPLACE VIEW `view_active_addresses` AS SELECT a.* FROM `addresses` a JOIN view_active_companies c ON a.company_id = c.company_id WHERE a.is_deleted = FALSE;
CREATE OR REPLACE VIEW `view_active_contacts` AS SELECT ct.* FROM `contacts` ct WHERE ct.is_deleted = FALSE;

CREATE OR REPLACE VIEW `view_active_customers` AS SELECT cust.customer_id, cust.company_id, comp.company_name, comp.vat_number, comp.website, comp.preferred_currency_code, cust.account_manager_id, cust.account_status_id, cas.status_name AS account_status_name, cust.created_at, cust.updated_at FROM `customers` cust JOIN `view_active_companies` comp ON cust.company_id = comp.company_id JOIN `customer_account_statuses` cas ON cust.account_status_id = cas.status_id;
CREATE OR REPLACE VIEW `view_active_suppliers` AS SELECT supp.supplier_id, supp.company_id, comp.company_name, comp.vat_number, comp.website, comp.default_payment_terms, comp.preferred_currency_code, supp.created_at, supp.updated_at FROM `suppliers` supp JOIN `view_active_companies` comp ON supp.company_id = comp.company_id;
CREATE OR REPLACE VIEW `view_active_partners` AS SELECT p.partner_id, p.company_id, comp.company_name, p.partner_type_id, pt.type_name as partner_type_name, p.partnership_level, p.agreement_url, p.created_at, p.updated_at FROM `partners` p JOIN `view_active_companies` comp ON p.company_id = comp.company_id LEFT JOIN `partner_types` pt ON p.partner_type_id = pt.type_id;
CREATE OR REPLACE VIEW `view_active_products` AS SELECT p.* FROM `products` p WHERE p.is_deleted = FALSE;

CREATE OR REPLACE VIEW `view_low_stock_alert` AS SELECT p.product_id, p.sku, p.product_name, w.warehouse_id, w.warehouse_name, sl.quantity_on_hand, sl.quantity_reserved, sl.quantity_available, sl.quantity_on_order, sl.quantity_projected, sl.reorder_level FROM stock_levels sl JOIN view_active_products p ON sl.product_id = p.product_id JOIN warehouses w ON sl.warehouse_id = w.warehouse_id WHERE p.is_active = TRUE AND sl.reorder_level IS NOT NULL AND sl.quantity_projected <= sl.reorder_level;

CREATE OR REPLACE VIEW `view_sales_by_country_month` AS SELECT co.country_name, co.country_code_iso2, co.region, YEAR(o.order_date) AS sales_year, MONTH(o.order_date) AS sales_month, o.currency_code, COUNT(DISTINCT o.order_id) AS number_of_orders, SUM(oi.quantity) AS total_units_sold, SUM(oi.line_total) AS total_revenue FROM orders o JOIN order_items oi ON o.order_id = oi.order_id JOIN view_active_companies comp ON o.company_id = comp.company_id JOIN order_statuses os ON o.order_status_id = os.status_id LEFT JOIN view_active_addresses bill_addr ON o.billing_address_id = bill_addr.address_id LEFT JOIN countries co ON bill_addr.country_id = co.country_id WHERE os.status_name NOT IN ('Cancelled', 'Pending', 'On Hold') GROUP BY co.country_name, co.country_code_iso2, co.region, sales_year, sales_month, o.currency_code ORDER BY sales_year DESC, sales_month DESC, co.country_name;

CREATE OR REPLACE VIEW `view_overdue_customer_invoices` AS
SELECT
    ic.invoice_id,
    ic.invoice_number,
    comp.company_id,
    comp.company_name,
    primary_cust_contact.email AS primary_customer_contact_email,
    primary_cust_contact.first_name AS primary_contact_first_name,
    primary_cust_contact.last_name AS primary_contact_last_name,
    ic.invoice_date,
    ic.due_date,
    ic.total_amount,
    ic.amount_paid,
    ic.balance_due,
    ic.currency_code,
    DATEDIFF(CURDATE(), ic.due_date) AS days_overdue,
    u_acct_mgr.email AS account_manager_email,
    u_creator.email AS invoice_creator_email,
    ist.status_name AS invoice_status
FROM
    invoices_customer ic
JOIN
    view_active_companies comp ON ic.company_id = comp.company_id
JOIN
    customers cust ON comp.company_id = cust.company_id
JOIN
    invoice_statuses ist ON ic.invoice_status_id = ist.status_id
LEFT JOIN
    view_active_users u_acct_mgr ON cust.account_manager_id = u_acct_mgr.user_id
LEFT JOIN
    view_active_users u_creator ON ic.created_by_user_id = u_creator.user_id
LEFT JOIN
    customer_contacts cc ON cust.customer_id = cc.customer_id AND cc.is_primary_for_customer = TRUE
LEFT JOIN
    view_active_contacts primary_cust_contact ON cc.contact_id = primary_cust_contact.contact_id
WHERE
    ist.status_name NOT IN ('Paid', 'Void', 'Write-Off', 'Draft') AND ic.due_date IS NOT NULL AND ic.due_date < CURDATE()
ORDER BY
    days_overdue DESC, ic.balance_due DESC;

-- Final step: Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS=1;

-- ============================================
-- HOW TO CHECK DB SCHEMA VERSION
-- ============================================
-- To check the currently applied schema version from within SQL, run:
--
-- SELECT version_tag, description, applied_at, applied_by, script_checksum_algo, script_checksum
-- FROM db_schema_version
-- ORDER BY applied_at DESC, version_id DESC
-- LIMIT 1;
--
-- PROCESS FOR DEPLOYMENT:
-- 1. Ensure this script file contains '%%SCRIPT_CHECKSUM_PLACEHOLDER%%' for the script_checksum value
--    AND '_YOUR_SCRIPT_CHECKSUM_ALGO_HERE_' for script_checksum_algo.
-- 2. Choose your checksum algorithm (e.g., 'SHA256', 'MD5').
-- 3. Calculate the checksum of THIS SCRIPT FILE (the one containing the placeholders).
--    Example (Linux/macOS, SHA256): sha256sum your_script_file.sql
--    Example (Linux/macOS, MD5):   md5sum your_script_file.sql
-- 4. In a TEMPORARY COPY of this script, or via a script that processes this file:
--    a. Replace '_YOUR_SCRIPT_CHECKSUM_ALGO_HERE_' with your chosen algorithm string (e.g., 'SHA256').
--    b. Replace '%%SCRIPT_CHECKSUM_PLACEHOLDER%%' with the actual checksum string calculated in step 3.
-- 5. Execute the modified/temporary script against the database.
-- The checksum stored in the database will be the checksum of the script *as it was when the placeholders were present*.
-- ============================================
