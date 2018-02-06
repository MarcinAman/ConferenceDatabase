IF EXISTS(
    SELECT *
    FROM sys.databases
    WHERE [name] = 'conference_database'
)
  DROP DATABASE conference_database;
CREATE DATABASE conference_database;
GO

USE conference_database;

-- HELPER FUNCTIONS

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'customers_email' AND TYPE = 'C')
  ALTER TABLE dbo.customers
    DROP CONSTRAINT customers_email;
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'validate_email' AND TYPE = 'FN')
  DROP FUNCTION [dbo].[validate_email]
GO

CREATE FUNCTION [dbo].[validate_email](@email NVARCHAR(255))
  RETURNS BIT
AS
  BEGIN
    RETURN
    CASE WHEN (
      PATINDEX('%[ &'',":;!+=\/()<>]%', @email) > 0 -- Invalid characters
      OR patindex('[@.-_]%', @email) > 0 -- Valid but cannot be starting character
      OR patindex('%[@.-_]', @email) > 0 -- Valid but cannot be ending character
      OR @email NOT LIKE '%@%.%' -- Must contain at least one @ and one .
      OR @email LIKE '%..%' -- Cannot have two periods in a row
      OR @email LIKE '%@%@%' -- Cannot have two @ anyWHERE
      OR @email LIKE '%.@%' OR @email LIKE '%@.%' -- Cannot have @ and . next to each other
    )
      THEN 0
    ELSE 1
    END
  END
GO

-- TABLES

IF OBJECT_ID('dbo.payments', 'U') IS NOT NULL
  DROP TABLE dbo.payments;

CREATE TABLE payments (
  id       INT IDENTITY  NOT NULL,
  order_id INT           NOT NULL,
  value    DECIMAL(8, 2) NULL,
  CONSTRAINT payments_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX payments_id_uindex
  ON payments (id)
GO

IF OBJECT_ID('dbo.conference_day_participants', 'U') IS NOT NULL
  BEGIN
    IF OBJECT_ID('workshop_participants_conference_day_participants', 'F') IS NOT NULL
      ALTER TABLE dbo.workshop_participants
        DROP CONSTRAINT workshop_participants_conference_day_participants;

    DROP TABLE dbo.conference_day_participants;
  END

CREATE TABLE conference_day_participants (
  id                INT IDENTITY NOT NULL,
  participant_id    INT          NOT NULL,
  conference_day_id INT          NOT NULL,
  CONSTRAINT conference_day_participant_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX conference_day_participant_id_uindex
  ON conference_day_participants (id)
GO

IF OBJECT_ID('dbo.conference_days', 'U') IS NOT NULL
  BEGIN
    IF OBJECT_ID('ConferenceDayParticipant_conference_days', 'F') IS NOT NULL
      ALTER TABLE dbo.conference_day_participants
        DROP CONSTRAINT ConferenceDayParticipant_conference_days;

    IF OBJECT_ID('order_items_conference_days', 'F') IS NOT NULL
      ALTER TABLE dbo.order_items
        DROP CONSTRAINT order_items_conference_days;

    IF OBJECT_ID('workshops_conference_days', 'F') IS NOT NULL
      ALTER TABLE dbo.workshops
        DROP CONSTRAINT workshops_conference_days;

    DROP TABLE dbo.conference_days;
  END

CREATE TABLE conference_days (
  id            INT IDENTITY NOT NULL,
  conference_id INT          NOT NULL,
  day           DATETIME     NOT NULL,
  seats         INT          NULL,
  CONSTRAINT conference_days_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX conference_days_id_uindex
  ON conference_days (id)
GO

IF OBJECT_ID('dbo.conference_has_pricing', 'U') IS NOT NULL
  DROP TABLE dbo.conference_has_pricing;

CREATE TABLE conference_has_pricing (
  id                    INT IDENTITY NOT NULL,
  conference_pricing_id INT          NOT NULL,
  conference_id         INT          NOT NULL,
  CONSTRAINT conference_has_pricing_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX conference_has_pricing_id_uindex
  ON conference_has_pricing (id)
GO

IF OBJECT_ID('dbo.conference_pricings', 'U') IS NOT NULL
  DROP TABLE dbo.conference_pricings;

CREATE TABLE conference_pricings (
  id         INT IDENTITY  NOT NULL,
  price      DECIMAL(8, 2) NOT NULL,
  since_date DATETIME      NOT NULL,
  CONSTRAINT conference_pricings_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX conference_pricings_id_uindex
  ON conference_pricings (id)
GO

IF OBJECT_ID('dbo.conferences', 'U') IS NOT NULL
  BEGIN
    IF OBJECT_ID('ConferenceHasPricing_conferences', 'F') IS NOT NULL
      ALTER TABLE dbo.conference_has_pricing
        DROP CONSTRAINT ConferenceHasPricing_conferences;


    IF OBJECT_ID('conference_day_conference', 'F') IS NOT NULL
      ALTER TABLE dbo.conference_days
        DROP CONSTRAINT conference_day_conference;

    DROP TABLE dbo.conferences;
  END

CREATE TABLE conferences (
  id         INT IDENTITY  NOT NULL,
  [name]     VARCHAR(50),
  start_time DATETIME      NOT NULL,
  end_time   DATETIME      NOT NULL,
  discount   NUMERIC(2, 2) NOT NULL,
  CONSTRAINT conferences_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX conferences_id_uindex
  ON conferences (id)
GO

IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL
  BEGIN
    IF OBJECT_ID('customers_payment', 'F') IS NOT NULL
      ALTER TABLE dbo.orders
        DROP CONSTRAINT customers_payment;

    IF OBJECT_ID('participants_customers', 'F') IS NOT NULL
      ALTER TABLE dbo.participants
        DROP CONSTRAINT participants_customers;

    DROP TABLE dbo.customers;
  END

CREATE TABLE customers (
  id         INT IDENTITY NOT NULL,
  name       VARCHAR(256) NOT NULL,
  phone      CHAR(12) CHECK (LEN(TRIM(phone)) = 9),
  NIP        VARCHAR(10),
  email      NVARCHAR(256),
  address    TEXT,
  zip_code   TEXT,
  country    TEXT,
  is_company BIT          NULL,
  CONSTRAINT customers_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX customers_id_uindex
  ON customers (id)
GO

IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL
  BEGIN
    IF OBJECT_ID('participants_order_items', 'F') IS NOT NULL
      ALTER TABLE dbo.participants
        DROP CONSTRAINT participants_order_items;
    DROP TABLE dbo.order_items;
  END

CREATE TABLE order_items (
  id                 INT IDENTITY NOT NULL,
  order_id           INT          NOT NULL,
  workshop_id        INT          NOT NULL,
  places_reserved    INT          NOT NULL,
  conference_days_id INT          NOT NULL,
  CONSTRAINT order_items_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX order_items_id_uindex
  ON order_items (id)
GO

IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL
  DROP TABLE dbo.orders;

CREATE TABLE orders (
  id           INT IDENTITY NOT NULL,
  customer_id  INT          NOT NULL,
  order_date   DATETIME     NOT NULL,
  is_cancelled BIT          NULL,
  CONSTRAINT orders_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX orders_id_uindex
  ON orders (id)
GO

IF OBJECT_ID('dbo.participants', 'U') IS NOT NULL
  DROP TABLE dbo.participants;

CREATE TABLE participants (
  id            INT IDENTITY NOT NULL,
  customer_id   INT          NOT NULL,
  order_item_id INT          NOT NULL,
  name          VARCHAR(256) NOT NULL,
  card_no       INT          NULL,
  CONSTRAINT participants_pk PRIMARY KEY (id)
);

SELECT *
FROM sys.objects
IF OBJECT_ID('dbo.workshop_participants', 'U') IS NOT NULL
  DROP TABLE dbo.workshop_participants;

CREATE TABLE workshop_participants (
  id                            INT IDENTITY NOT NULL,
  workshop_id                   INT          NOT NULL,
  conference_day_participant_id INT          NOT NULL,
  CONSTRAINT workshop_participants_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX participants_id_uindex
  ON participants (id)
GO

IF OBJECT_ID('dbo.workshops', 'U') IS NOT NULL
  DROP TABLE dbo.workshops;

CREATE TABLE workshops (
  id                INT IDENTITY  NOT NULL,
  conference_day_id INT           NOT NULL,
  title             TEXT          NOT NULL,
  places            INT           NOT NULL,
  price             DECIMAL(8, 2) NULL,
  start_time        DATETIME      NOT NULL,
  end_time          DATETIME      NOT NULL,
  CONSTRAINT workshops_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX workshops_id_uindex
  ON workshops (id)
GO

-- FOREIGN KEYS
IF OBJECT_ID('conference_day_participants_conference_days', 'F') IS NOT NULL
  ALTER TABLE dbo.conference_day_participants
    DROP CONSTRAINT conference_day_participants_conference_days;

ALTER TABLE conference_day_participants
  ADD CONSTRAINT conference_day_participants_conference_days
FOREIGN KEY (conference_day_id)
REFERENCES conference_days (id);

IF OBJECT_ID('conference_day_participants_participants', 'F') IS NOT NULL
  ALTER TABLE dbo.conference_day_participants
    DROP CONSTRAINT conference_day_participants_participants;

ALTER TABLE conference_day_participants
  ADD CONSTRAINT conference_day_participants_participants
FOREIGN KEY (participant_id)
REFERENCES participants (id);

IF OBJECT_ID('conference_has_pricing_conference_pricing', 'F') IS NOT NULL
  ALTER TABLE dbo.conference_has_pricing
    DROP CONSTRAINT conference_has_pricing_conference_pricing;

ALTER TABLE conference_has_pricing
  ADD CONSTRAINT conference_has_pricing_conference_pricing
FOREIGN KEY (conference_pricing_id)
REFERENCES conference_pricings (id);

IF OBJECT_ID('conference_has_pricing_conference', 'F') IS NOT NULL
  ALTER TABLE dbo.conference_has_pricing
    DROP CONSTRAINT conference_has_pricing_conference;

ALTER TABLE conference_has_pricing
  ADD CONSTRAINT conference_has_pricing_conferences
FOREIGN KEY (conference_id)
REFERENCES conferences (id);

IF OBJECT_ID('payments_orders', 'F') IS NOT NULL
  ALTER TABLE dbo.Payments
    DROP CONSTRAINT payments_orders;

ALTER TABLE payments
  ADD CONSTRAINT payments_orders
FOREIGN KEY (order_id)
REFERENCES orders (id);

IF OBJECT_ID('conference_day_conference', 'F') IS NOT NULL
  ALTER TABLE dbo.conference_days
    DROP CONSTRAINT conference_day_conference;

ALTER TABLE conference_days
  ADD CONSTRAINT conference_day_conference
FOREIGN KEY (conference_id)
REFERENCES conferences (id);

IF OBJECT_ID('customers_payment', 'F') IS NOT NULL
  ALTER TABLE dbo.orders
    DROP CONSTRAINT customers_payment;

ALTER TABLE orders
  ADD CONSTRAINT customers_payment
FOREIGN KEY (customer_id)
REFERENCES customers (id);

IF OBJECT_ID('order_items_conference_days', 'F') IS NOT NULL
  ALTER TABLE dbo.order_items
    DROP CONSTRAINT order_items_conference_days;

ALTER TABLE order_items
  ADD CONSTRAINT order_items_conference_days
FOREIGN KEY (conference_days_id)
REFERENCES conference_days (id);

IF OBJECT_ID('orders_order_items', 'F') IS NOT NULL
  ALTER TABLE dbo.order_items
    DROP CONSTRAINT orders_order_items;

ALTER TABLE order_items
  ADD CONSTRAINT orders_order_items
FOREIGN KEY (order_id)
REFERENCES orders (id);

IF OBJECT_ID('participants_customers', 'F') IS NOT NULL
  ALTER TABLE dbo.participants
    DROP CONSTRAINT participants_customers;

ALTER TABLE participants
  ADD CONSTRAINT participants_customers
FOREIGN KEY (customer_id)
REFERENCES customers (id);

IF OBJECT_ID('participants_order_items', 'F') IS NOT NULL
  ALTER TABLE dbo.participants
    DROP CONSTRAINT participants_order_items;

ALTER TABLE participants
  ADD CONSTRAINT participants_order_items
FOREIGN KEY (order_item_id)
REFERENCES order_items (id);

IF OBJECT_ID('workshop_participants_conference_day_participants', 'F') IS NOT NULL
  ALTER TABLE dbo.workshop_participants
    DROP CONSTRAINT workshop_participants_conference_day_participants;

ALTER TABLE workshop_participants
  ADD CONSTRAINT workshop_participants_conference_day_participants
FOREIGN KEY (conference_day_participant_id)
REFERENCES conference_day_participants (id);

IF OBJECT_ID('workshops_conference_days', 'F') IS NOT NULL
  ALTER TABLE dbo.workshops
    DROP CONSTRAINT workshops_conference_days;

IF OBJECT_ID('customers_email', 'F') IS NOT NULL
  ALTER TABLE dbo.customers
    DROP CONSTRAINT customers_email;

ALTER TABLE customers
  ADD CONSTRAINT customers_email
CHECK ([dbo].[validate_email](email) = 1);

ALTER TABLE workshops
  ADD CONSTRAINT workshops_conference_days
FOREIGN KEY (conference_day_id)
REFERENCES conference_days (id);

IF OBJECT_ID('workshops_order_items', 'F') IS NOT NULL
  ALTER TABLE dbo.order_items
    DROP CONSTRAINT workshops_order_items;

ALTER TABLE order_items
  ADD CONSTRAINT workshops_order_items
FOREIGN KEY (workshop_id)
REFERENCES workshops (id);

IF OBJECT_ID('workshops_workshop_participants', 'F') IS NOT NULL
  ALTER TABLE dbo.workshop_participants
    DROP CONSTRAINT workshops_workshop_participants;

ALTER TABLE workshop_participants
  ADD CONSTRAINT workshops_workshop_participants
FOREIGN KEY (workshop_id)
REFERENCES workshops (id);

-- PROCEDURES

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'create_conference') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[create_conference]
GO

CREATE PROCEDURE [dbo].[create_conference](
  @name          NVARCHAR(127),
  @start_time    DATETIME,
  @end_time      DATETIME,
  @discount      DECIMAL(2, 2),

  @conference_id INT = NULL OUT
) AS BEGIN
  SET NOCOUNT ON;

  BEGIN TRY
  BEGIN TRANSACTION;
  IF @name IS NULL OR LTRIM(@name) = ''
    THROW 50000, '@name is NULL or empty', 1
  IF @start_time >= @end_time
    THROW 50000, '@start_time is later or equal than @end_time', 1
  IF @start_time < GETDATE()
    THROW 50000, '@start_time is from past', 1

  INSERT INTO conferences (
    [name],
    start_time,
    end_time,
    discount
  ) VALUES (
    @name,
    @start_time,
    @end_time,
    @discount
  )
  SET @conference_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'create_workshop') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[create_workshop]
GO

CREATE PROCEDURE [dbo].[create_workshop]
    @conference_day_id INT,
    @title             VARCHAR(256),
    @places            INT,
    @price             DECIMAL(8, 2),
    @start_time        DATETIME,
    @end_time          DATETIME,
    @workshop_id       INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION;
  IF @start_time >= @end_time
    THROW 50000, '@start_time is later or equal than @end_time', 1
  IF @start_time < GETDATE()
    THROW 50000, '@start_time is from past', 1
  IF @price < 0
    THROW 50000, '@price is lower than 0', 1
  IF @places <= 0
    THROW 50000, '@seats are lower or equal 0', 1
  IF NOT EXISTS(SELECT *
                FROM conference_days
                WHERE conference_days.id = @conference_day_id)
    THROW 50000, '@Conference_day not found', 1

  INSERT INTO workshops (
    conference_day_id,
    title,
    places,
    price,
    start_time,
    end_time
  ) VALUES (
    @conference_day_id,
    @title,
    @places,
    @price,
    @start_time,
    @end_time
  )
  SET @workshop_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_customer') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_customer]
GO

CREATE PROCEDURE [dbo].[add_customer]
    @name        VARCHAR(256),
    @phone       CHAR(9),
    @NIP         CHAR(10),
    @email       NVARCHAR(256),
    @adress      TEXT,
    @zip_code    TEXT,
    @county      TEXT,
    @is_company  BIT,
    @customer_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF (@phone IS NULL) AND (@email IS NULL)
    THROW 50000, '@phone and @email is null. No contact with customer', 1
  IF @name IS NULL OR LTRIM(@name) = ''
    THROW 50000, '@name is null or empty', 1
  INSERT INTO customers (
    [name],
    phone,
    NIP,
    email,
    address,
    zip_code,
    country,
    is_company
  ) VALUES (
    @name,
    @phone,
    @NIP,
    @email,
    @adress,
    @zip_code,
    @county,
    @is_company
  )

  SET @customer_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_conference_day') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_conference_day]
GO

CREATE PROCEDURE [dbo].[add_conference_day]
    @conference_id     INT,
    @day               DATETIME,
    @places            INT,
    @conference_day_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM conferences
                WHERE id = @conference_id)
    THROW 50000, '@conference_id is invalid. No such conference', 1
  IF @day < GETDATE()
    THROW 50000, '@date is from past', 1
  IF EXISTS(SELECT id
            FROM conference_days
            WHERE conference_id = @conference_id AND [day] = @day)
    THROW 50000, 'Conference already in database', 1
  IF @places <= 0
    THROW 50000, '@places are lower or equal 0', 1

  INSERT INTO conference_days (
    conference_id,
    [day],
    seats
  ) VALUES (
    @conference_id,
    @day,
    @places
  )
  SET @conference_day_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_order') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_order]
GO

CREATE PROCEDURE [dbo].[add_order]
    @phone    CHAR(9),
    @email    NVARCHAR(256),
    @order_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  DECLARE @customerid INT, @orderdate DATETIME

  IF @phone IS NOT NULL AND @email IS NOT NULL
    BEGIN
      SET @customerid = (SELECT id
                         FROM customers
                         WHERE phone LIKE @phone AND email LIKE @email)
    END
  IF @phone IS NULL
    BEGIN
      SET @customerid = (SELECT id
                         FROM customers
                         WHERE email LIKE @email)
    END
  IF @email IS NULL
    BEGIN
      SET @customerid = (SELECT id
                         FROM customers
                         WHERE phone LIKE @phone)
    END
  IF @customerid IS NULL
    THROW 50000, 'No such customer in database', 1

  SET @orderdate = GETDATE()
  INSERT INTO orders (
    customer_id,
    order_date,
    is_cancelled
  ) VALUES (
    @customerid,
    @orderdate,
    0
  )
  SET @order_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_order_item') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_order_item]
GO

CREATE PROCEDURE [dbo].[add_order_item]
    @order_id          INT,
    @workshop_id       INT,
    @conference_day_id INT,
    @places_reserved   INT,
    @order_item_id     INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM orders
                WHERE id = @order_id)
    THROW 50000, '@order_id not in database', 1
  IF NOT EXISTS(SELECT *
                FROM conference_days
                WHERE id = @conference_day_id)
    THROW 50000, '@conference_day_id not in database', 1
  IF NOT EXISTS(SELECT *
                FROM workshops
                WHERE id = @workshop_id)
    THROW 50000, '@workshop not in database', 1
  IF @places_reserved <= 0
    THROW 50000, '@places_reserved below or equal 0', 1

  INSERT INTO order_items (
    order_id,
    workshop_id,
    conference_days_id,
    places_reserved
  ) VALUES (
    @order_id,
    @workshop_id,
    @conference_day_id,
    @places_reserved
  )
  SET @order_item_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_participant') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_participant]
GO

CREATE PROCEDURE [dbo].[add_participant]
    @customer_id    INT,
    @order_item_id  INT,
    @name           VARCHAR(256),
    @participant_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM customers
                WHERE id = @customer_id)
    THROW 50000, '@customer_id not in database', 1
  IF NOT EXISTS(SELECT *
                FROM order_items
                WHERE id = @order_item_id)
    THROW 50000, '@order_item not in database', 1
  IF LTRIM(@name) = ''
    THROW 50000, '@name is empty', 1
  IF (
       SELECT count(id)
       FROM participants
       WHERE order_item_id = @order_item_id
     ) >= (
       SELECT places_reserved
       FROM order_items
       WHERE id = @order_item_id
     )
    THROW 50000, 'No more places left in this order_item', 1

  INSERT INTO participants (
    customer_id,
    order_item_id,
    [name]
  ) VALUES (
    @customer_id,
    @order_item_id,
    @name
  )
  SET @participant_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_student_participant') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_student_participant]
GO

CREATE PROCEDURE [dbo].[add_student_participant]
    @customer_id   INT,
    @order_item_id INT,
    @name          VARCHAR(256),
    @card_no       INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM customers
                WHERE id = @customer_id)
    THROW 50000, '@customer_id not in database', 1
  IF NOT EXISTS(SELECT *
                FROM order_items
                WHERE id = @order_item_id)
    THROW 50000, '@order_item not in database', 1
  IF LTRIM(@name) = ''
    THROW 50000, '@name is empty', 1
  IF (
       SELECT count(id)
       FROM participants
       WHERE order_item_id = @order_item_id
     ) >= (
       SELECT places_reserved
       FROM order_items
       WHERE id = @order_item_id
     )
    THROW 50000, 'No more places left in this order_item', 1

  INSERT INTO participants (
    customer_id,
    order_item_id,
    [name],
    card_no
  ) VALUES (
    @customer_id,
    @order_item_id,
    @name,
    @card_no
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_workshop_participant') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_workshop_participant]
GO

CREATE PROCEDURE [dbo].[add_workshop_participant]
    @workshop_id                   INT,
    @conference_day_participant_id INT,
    @participant_id                INT,
    @order_item_id                 INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF (
       SELECT count(id)
       FROM workshop_participants
       WHERE workshop_id = @workshop_id
     ) >= (
       SELECT places
       FROM workshops
       WHERE id = @workshop_id
     )
    THROW 50000, 'No more places left in this workshop', 1
  IF (
       SELECT count(wp.id)
       FROM workshop_participants AS wp
         INNER JOIN conference_day_participants AS cdp ON wp.conference_day_participant_id = cdp.id
         INNER JOIN participants AS p ON p.id = cdp.participant_id
       WHERE p.id = @participant_id
     ) >= (
       SELECT places_reserved
       FROM order_items
       WHERE id = @order_item_id
     )
    THROW 50000, 'No more places left available in this order', 1

  INSERT INTO workshop_participants (
    workshop_id,
    conference_day_participant_id
  ) VALUES (
    @workshop_id,
    @conference_day_participant_id
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_payment') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_payment]
GO

CREATE PROCEDURE [dbo].[add_payment]
    @value    DECIMAL(8, 2),
    @order_id INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT id
                FROM orders
                WHERE id = @order_id)
    THROW 50000, '@order_id not in database', 1

  INSERT INTO payments (
    [value],
    order_id
  ) VALUES (
    @value,
    @order_id
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_conference_day_participant') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_conference_day_participant]
GO

CREATE PROCEDURE [dbo].[add_conference_day_participant]
    @participant_id                INT,
    @conference_day_id             INT,
		@conference_day_participant_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT id
                FROM participants
                WHERE id = @participant_id)
    THROW 50000, '@participant_id not in database', 1
  IF NOT EXISTS(SELECT id
                FROM conference_days
                WHERE id = @conference_day_id)
    THROW 50000, '@conference_day_id not in database', 1
  IF EXISTS(SELECT id
            FROM conference_day_participants
            WHERE participant_id = @participant_id AND conference_day_id = @conference_day_id)
    THROW 50000, 'Participant already enrolled for this conference day', 1

  INSERT INTO conference_day_participants (
    conference_day_id,
    participant_id
  ) VALUES (
    @conference_day_id,
    @participant_id
  )
	SET @conference_day_participant_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_conference_pricing') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_conference_pricing]
GO

CREATE PROCEDURE [dbo].[add_conference_pricing]
    @price                 DECIMAL(8, 2),
    @since_date            DATETIME,
    @conference_pricing_id INT = NULL OUT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF @price < 0
    THROW 50000, '@price is lower than 0', 1

  INSERT INTO conference_pricings (
    price,
    since_date
  ) VALUES (
    @price,
    @since_date
  )
  SET @conference_pricing_id = SCOPE_IDENTITY()
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'add_conference_has_pricing') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[add_conference_has_pricing]
GO

CREATE PROCEDURE [dbo].[add_conference_has_pricing]
    @conference_pricing_id INT,
    @conference_id         INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT id
                FROM conferences
                WHERE id = @conference_id)
    THROW 50000, '@conference_id not in database', 1
  IF NOT EXISTS(SELECT id
                FROM conference_pricings
                WHERE id = @conference_pricing_id)
    THROW 50000, '@conference_pricing_id not in database', 1

  INSERT INTO conference_has_pricing (
    conference_id,
    conference_pricing_id
  ) VALUES (
    @conference_id,
    @conference_pricing_id
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

-- PROCEDURES FOR UPDATING
IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'update_customer_data') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[update_customer_data]
GO

CREATE PROCEDURE [dbo].[update_customer_data]
    @customer_id INT,
    @name        VARCHAR(256),
    @phone       CHAR(9),
    @NIP         CHAR(10),
    @email       TEXT,
    @address     TEXT,
    @zip_code    TEXT,
    @county      TEXT,
    @is_company  BIT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM customers
                WHERE id = @customer_id)
    THROW 50000, 'Customer not in database', 1
  IF (@phone IS NULL) AND (@email IS NULL)
    THROW 50000, '@phone and @email is null. Customer must provide contact method', 1
  IF @name IS NULL OR LTRIM(@name) = ''
    THROW 50000, '@name is null or empty', 1
  UPDATE customers
  SET [name]   = @name,
    phone      = @phone,
    NIP        = @NIP,
    email      = @email,
    address    = @address,
    zip_code   = @zip_code,
    country    = @county,
    is_company = @is_company
  WHERE customers.id = @customer_id
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'delete_customer') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[delete_customer]
GO

CREATE PROCEDURE [dbo].[delete_customer]
    @customer_id INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF EXISTS(SELECT *
            FROM orders
            WHERE customer_id = @customer_id)
    THROW 50000, 'Customer data cannot be removed, an order was made', 1
  DELETE customers
  WHERE id = @customer_id
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'delete_conference_pricing') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[delete_conference_pricing]
GO

CREATE PROCEDURE [dbo].[delete_conference_pricing]
    @conference_pricing_id INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF EXISTS(SELECT *
            FROM conference_has_pricing
            WHERE conference_pricing_id = @conference_pricing_id)
    THROW 50000, 'Conference pricing is used by conference. Cant remove that value', 1

  DELETE conference_pricings
  WHERE id = @conference_pricing_id
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'return_payment') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[return_payment]
GO
--This only allows returns of money in 1:1 ratio.

CREATE PROCEDURE [dbo].[return_payment]
    @payment_id INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM payments
                WHERE id = @payment_id)
    THROW 50000, 'Payment not found', 1

  DECLARE @value DECIMAL(8, 2)
  SET @value = (SELECT [value] * (-1)
                FROM payments
                WHERE id = @payment_id)

  DECLARE @order_id INT
  SET @order_id = (SELECT order_id
                   FROM payments
                   WHERE id = @payment_id)

  IF EXISTS(SELECT *
            FROM payments
            WHERE order_id = @order_id AND [value] < 0)
    THROW 50000, 'Money was already returned from that transaction', 1

  INSERT INTO payments (
    [value],
    order_id
  ) VALUES (
    @value,
    @order_id
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'update_workshop_information') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[update_workshop_information]
GO

CREATE PROCEDURE [dbo].[update_workshop_information]
    @workshop_id INT,
    @title       VARCHAR(256),
    @places      INT,
    @price       DECIMAL(8, 2)
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM workshops
                WHERE id = @workshop_id)
    THROW 50000, 'Workshop not found', 1
  IF LTRIM(@title) = ''
    THROW 50000, 'Title is empty', 1
  IF @places <= 0
    THROW 50000, 'Places are lower or equal 0', 1
  IF @price < 0
    THROW 50000, 'Price is lower than 0', 1

  UPDATE workshops
  SET title = @title,
    places  = @places,
    price   = @price
  WHERE id = @workshop_id
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'change_workshop_time') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[change_workshop_time]
GO


CREATE PROCEDURE [dbo].[change_workshop_time]
    @workshop_id INT,
    @start_time  DATETIME,
    @end_time    DATETIME
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM workshops
                WHERE id = @workshop_id)
    THROW 50000, 'Workshop not found', 1
  IF @start_time >= @end_time
    THROW 50000, 'Start time is later than endtime', 1
  IF day(@start_time) != day(@end_time)
    THROW 50000, 'Begining and end days have to be the same', 1
  IF EXISTS(SELECT *
            FROM order_items
            WHERE id = @workshop_id)
    THROW 50000, 'There is at least 1 person enrolled for this workshop. Can change the time', 1

  UPDATE workshops
  SET start_time = @start_time,
    end_time     = @end_time
  WHERE id = @workshop_id

  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'cancel_order') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[cancel_order]
GO

CREATE PROCEDURE [dbo].[cancel_order]
    @order_id INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  IF NOT EXISTS(SELECT *
                FROM orders
                WHERE id = @order_id)
    THROW 50000, 'Order not in database', 1
  UPDATE orders
  SET is_cancelled = 1
  WHERE id = @order_id

  DECLARE @orderItemID INT
  SET @orderItemID = (SELECT id
                      FROM order_items
                      WHERE order_id = @order_id)

  DELETE conference_day_participants
  WHERE id IN (
    SELECT cdp.id
    FROM conference_day_participants AS cdp
      INNER JOIN workshop_participants AS wp ON wp.conference_day_participant_id = cdp.id
      INNER JOIN order_items AS oi ON oi.id = @orderItemID AND oi.workshop_id = wp.workshop_id
  )

  DELETE workshop_participants
  WHERE id IN (SELECT wp.id
               FROM workshop_participants AS wp
                 INNER JOIN conference_day_participants AS cdp ON wp.conference_day_participant_id = cdp.id
                 INNER JOIN participants AS p ON p.id = cdp.participant_id
               WHERE p.order_item_id IN
                     (SELECT oi.id
                      FROM order_items AS oi
                        INNER JOIN orders AS o ON o.id = oi.order_id
                      WHERE o.id = @order_id
                     )
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID(N'cancel_unpaid_orders') AND TYPE IN (N'P', N'PC'))
  DROP PROCEDURE [dbo].[cancel_unpaid_orders]
GO

CREATE PROCEDURE [dbo].[cancel_unpaid_orders]
    @days INT
AS BEGIN
  BEGIN TRY
  BEGIN TRANSACTION
  UPDATE orders
  SET is_cancelled = 1
  WHERE id IN (
    SELECT orders.id
    FROM orders
      LEFT OUTER JOIN payments ON payments.order_id = orders.id
    WHERE datediff(DAY, order_date, GETDATE()) >= @days AND payments.order_id IS NULL
  )
  COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
  ROLLBACK TRANSACTION;
  THROW
  END CATCH
END
GO

--FUNCTIONS

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'does_workshops_overlap' AND TYPE = 'FN')
  DROP FUNCTION [dbo].[does_workshops_overlap]
GO

CREATE FUNCTION [dbo].[does_workshops_overlap](@workshop_id1 INT, @workshop_id2 INT)
  RETURNS BIT
AS BEGIN
  DECLARE
  @start_time1 DATETIME,
  @start_time2 DATETIME,
  @end_time1 DATETIME,
  @end_time2 DATETIME
  SET @start_time1 = (SELECT start_time
                      FROM workshops
                      WHERE id = @workshop_id1)
  SET @start_time2 = (SELECT start_time
                      FROM workshops
                      WHERE id = @workshop_id2)
  SET @end_time1 = (SELECT end_time
                    FROM workshops
                    WHERE id = @workshop_id1)
  SET @end_time2 = (SELECT end_time
                    FROM workshops
                    WHERE id = @workshop_id2)
  IF ((@start_time1 < @start_time2 AND @end_time2 > @end_time1)
      OR (@start_time2 > @start_time1 AND @end_time2 < @end_time1)
      OR (@start_time2 < @start_time1 AND @end_time2 < @end_time1))
    RETURN 1
  RETURN 0
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'get_free_day_places' AND TYPE = 'FN')
  DROP FUNCTION [dbo].[get_free_day_places]
GO

CREATE FUNCTION [dbo].[get_free_day_places](@conference_day_id INT)
  RETURNS INT
AS BEGIN
  RETURN (
           SELECT seats
           FROM conference_days
           WHERE id = @conference_day_id
         ) - (SELECT sum(oi.places_reserved)
              FROM order_items AS oi
                INNER JOIN orders AS o ON o.id = oi.order_id AND o.is_cancelled = 0
                INNER JOIN workshops AS w ON w.id = oi.workshop_id
              WHERE w.conference_day_id = @conference_day_id
         )
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'get_free_workshop_seats' AND TYPE = 'FN')
  DROP FUNCTION [dbo].[get_free_workshop_seats]
GO

CREATE FUNCTION [dbo].[get_free_workshop_seats](@workshop_id INT)
  RETURNS INT
AS BEGIN
  RETURN (
           SELECT places
           FROM workshops
           WHERE id = @workshop_id
         ) - (
           SELECT count(*)
           FROM order_items AS oi
             INNER JOIN orders AS o ON oi.order_id = o.id AND o.is_cancelled = 0
           WHERE workshop_id = @workshop_id
         );
END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'get_conference_day_participants' AND TYPE = 'IF')
  DROP FUNCTION [dbo].[get_conference_day_participants]
GO

CREATE FUNCTION [dbo].[get_conference_day_participants](@ConferenceDayID INT)
  RETURNS TABLE
  AS
  RETURN(
  SELECT
    part.id,
    [name]
  FROM participants AS part
    INNER JOIN conference_day_participants ON participant_id = part.id
  WHERE conference_day_id = @ConferenceDayID
  );
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'get_workshop_participants' AND TYPE = 'IF')
  DROP FUNCTION [dbo].[get_workshop_participants]
GO

CREATE FUNCTION [dbo].[get_workshop_participants](@workshopID INT)
  RETURNS TABLE
  AS
  RETURN(
  SELECT
    [name],
    part.id
  FROM participants AS part
    INNER JOIN conference_day_participants AS cdpart ON cdpart.participant_id = part.id
    INNER JOIN workshop_participants AS wp ON wp.conference_day_participant_id = cdpart.id
    INNER JOIN workshops AS w ON w.id = wp.workshop_id
  WHERE w.id = @workshopID
  );
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'get_customers_with_not_filled_participants' AND TYPE = 'IF')
  DROP FUNCTION [dbo].[get_customers_with_not_filled_participants]
GO

-- If there is at least one participant specified, we assume that client is
-- happy with the number of participants they filled and is not interested in
-- remaining places.
CREATE FUNCTION [dbo].[get_customers_with_not_filled_participants](@amountOfDays INT)
  RETURNS TABLE
  AS
  RETURN(SELECT
           cust.id            AS 'Customer ID',
           o.id               AS 'Order ID',
           od.places_reserved AS 'Seats'
         FROM customers AS cust
           INNER JOIN orders AS o ON o.customer_id = cust.id
           INNER JOIN order_items AS od ON od.order_id = o.id
         WHERE od.id NOT IN
               (SELECT p.order_item_id
                FROM participants AS p
                  INNER JOIN customers AS cus ON cus.id = p.customer_id AND cus.id = cust.id
                  INNER JOIN conference_day_participants AS cdp ON cdp.participant_id = p.id
                  INNER JOIN conference_days AS cd ON cd.id = cdp.conference_day_id
                  INNER JOIN conferences AS c ON c.id = cd.conference_id
               )
               AND datediff(DAY, o.order_date, GETDATE()) < @amountOfDays
  );
GO

--TRIGGERS

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'too_few_places_on_workshop_to_order' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[too_few_places_on_workshop_to_order]
GO

CREATE TRIGGER [dbo].[too_few_places_on_workshop_to_order]
  ON [dbo].[order_items]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT oi.workshop_id
              FROM order_items AS oi INNER JOIN workshops AS w ON w.id = oi.workshop_id
              WHERE (SELECT sum(o.places_reserved)
                     FROM order_items AS o
                     GROUP BY o.workshop_id
                     HAVING o.workshop_id = w.id) > w.places)
      THROW 50000, 'Too few places on workshop', 1
  END
GO

-- IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 'too_few_places_on_workshop_on_participants' AND TYPE = 'TR')
-- DROP TRIGGER [dbo].[too_few_places_on_workshop_on_participants]
-- GO
--
-- CREATE TRIGGER [dbo].[too_few_places_on_workshop_on_participants] --to samo tylko na partycypantach.
-- --Sadzac po opiniach na wiki dobrze jest cos takiego zrobic bo siwik sprawdza randomowe dzialanie
-- ON [dbo].[workshop_participants]
-- AFTER INSERT,UPDATE
-- AS BEGIN
-- 	DECLARE @workshop_id INT
-- 	SET @workshop_id = (SELECT workshop_id FROM inserted)
--
-- 	DECLARE @places INT
-- 	SET @places = (SELECT places FROM workshops WHERE workshops.id = @workshop_id)
--
-- 	DECLARE @currentlyTaken INT
-- 	SET @currentlyTaken = (
-- 		SELECT sum(oi.places_reserved) FROM order_items AS oi
-- 		INNER JOIN orders AS o ON o.id = oi.order_id AND o.is_cancelled = 0
-- 		WHERE oi.workshop_id = @workshop_id
-- 	)
-- 	IF @currentlyTaken > @places
-- 		THROW 50000, 'Cannot continue, lack of seats on workshop', 1
-- END
-- GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'too_few_places_on_conference_day_on_order' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[too_few_places_on_conference_day_on_order]
GO

CREATE TRIGGER [dbo].[too_few_places_on_conference_day_on_order]
  ON [dbo].[order_items]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM conference_days AS cd
                INNER JOIN inserted AS i ON i.conference_days_id = cd.id
              WHERE dbo.get_free_day_places(cd.id) < 0)
      THROW 50000, 'Too few places on conference day', 1
  END
GO


-- W sumie to nie wiem czy to chcemy. Bo kto bogatemu zabroni zapisac sie na wszystkie warsztaty?
-- Jesli tak to w sumie trzeba przerobic bo jest tak, jakby inserted i updated bylo pojedynczymi rekordami

-- IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 'already_enrolled_on_other_workshop' AND TYPE = 'TR')
-- DROP TRIGGER [dbo].[already_enrolled_on_other_workshop]
-- GO
--
-- CREATE TRIGGER [dbo].[already_enrolled_on_other_workshop]
-- ON [dbo].[workshop_participants]
-- AFTER INSERT, UPDATE
-- AS BEGIN
-- 		DECLARE @workshop_id INT
-- 		DECLARE @conference_day_participant_id INT
-- 		SET @workshop_id = (SELECT workshop_id FROM inserted)
-- 		SET @conference_day_participant_id = (SELECT conference_day_participant_id FROM inserted)
--
-- 		IF (SELECT count(*) FROM workshops AS w
-- 			WHERE dbo.does_workshops_overlap(@workshop_id,w.id) = 1 AND @workshop_id <> w.id
-- 		) > 1
-- 			THROW 50000, 'Participant already enrolled for another workshop at the same time', 1
-- END
-- GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'workshop_conference_day_connection' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[workshop_conference_day_connection]
GO

CREATE TRIGGER [dbo].[workshop_conference_day_connection]
  ON [dbo].[workshops]
  AFTER INSERT, UPDATE
AS
  BEGIN
    -- Are all workshops connected to a conference day?
    IF (SELECT count(*)
        FROM conference_days AS cd
          INNER JOIN inserted AS i ON i.conference_day_id = cd.id)
       <> (SELECT count(*)
           FROM conference_days
           WHERE id IN (SELECT DISTINCT conference_day_id
                        FROM inserted))
      THROW 50000, 'At least one conference day is not connected to conference', 1

    -- Will they be enough places left on the conference day after adding this workshop?
    IF EXISTS(SELECT *
              FROM conference_days AS cd INNER JOIN inserted AS i ON i.conference_day_id = cd.id
              WHERE (SELECT sum(places)
                     FROM workshops
                     WHERE conference_day_id = cd.id) > cd.seats)
      THROW 50000, 'Not enough seats on this conference day. Cant add this workshop', 1

    -- Is workshop during the claimed conference day?
    IF EXISTS(SELECT *
              FROM inserted AS i INNER JOIN conference_days AS cd
                  ON cd.id = i.conference_day_id AND datediff(DAY, cd.day, i.start_time) <> 0)
      THROW 50000, 'Workshop is not in the time of a conference day', 1
  END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'conference_conference_day_connection' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[conference_conference_day_connection]
GO

CREATE TRIGGER [dbo].[conference_conference_day_connection]
  ON [dbo].[conference_days]
  AFTER INSERT, UPDATE, DELETE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS i LEFT OUTER JOIN conferences AS c ON i.conference_id = c.id
              WHERE c.start_time = NULL)
      THROW 50000, 'Conference id not in database', 1

    IF EXISTS(SELECT *
              FROM inserted AS i INNER JOIN conferences AS c
                  ON c.id = i.conference_id AND i.[day] NOT BETWEEN c.start_time AND c.end_time)
      THROW 50000, 'Conference day not in conference time', 1

    IF EXISTS(SELECT *
              FROM inserted AS i INNER JOIN conference_days AS cd ON cd.[day] = i.[day]
              GROUP BY i.conference_id
              HAVING count(*) > 1)
      THROW 50000, 'There is already a conference day in this date', 1
  END

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'order_date_unchangable' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[order_date_unchangable]
GO

CREATE TRIGGER [dbo].[order_date_unchangable]
  ON [dbo].[orders]
  AFTER UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS i INNER JOIN deleted AS d ON d.id = i.id
              WHERE d.order_date <> i.order_date)
      THROW 50000, 'Order date cant be changed', 1
  END
GO

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'order_items_parameters' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[order_items_parameters]
GO

CREATE TRIGGER [dbo].[order_items_parameters]
  ON [dbo].[order_items]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS i LEFT OUTER JOIN workshops AS w ON w.id = i.workshop_id
              WHERE w.conference_day_id IS NULL)
      THROW 50000, 'Workshop not in database', 1

    IF EXISTS(SELECT *
              FROM inserted AS i LEFT OUTER JOIN conference_days AS cd ON cd.id = i.conference_days_id
              WHERE cd.day IS NULL)
      THROW 50000, 'Conference day not in database', 1

    IF (SELECT places_reserved
        FROM inserted) < 0
      THROW 50000, 'Places reserved are lower than 0', 1

    IF (SELECT count(*)
        FROM workshops AS w INNER JOIN conference_days AS cd ON cd.id = w.conference_day_id
          INNER JOIN inserted AS i ON i.workshop_id = w.id AND cd.id = i.conference_days_id) <> (SELECT count(*)
                                                                                                 FROM inserted)
      THROW 50000, 'Workshop not in this conference day', 1
  END

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'participants_connections' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[participants_connections]
GO

CREATE TRIGGER [dbo].[participants_connections]
  ON [dbo].[participants]
  AFTER INSERT, UPDATE, DELETE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS p LEFT OUTER JOIN customers AS c ON c.id = p.id
              WHERE c.is_company IS NULL)
      THROW 50000, 'Customer id not found', 1
    IF EXISTS(SELECT *
              FROM inserted AS p LEFT OUTER JOIN order_items AS oi ON oi.id = p.id
              WHERE oi.order_id IS NULL)
      THROW 50000, 'Order item id not in database', 1
    IF EXISTS(SELECT *
              FROM inserted AS i INNER JOIN order_items AS oi ON oi.id = i.order_item_id
                INNER JOIN orders AS o ON o.id = oi.order_id
                INNER JOIN customers AS c ON c.id = o.id
              WHERE c.id NOT IN (SELECT customer_id
                                 FROM inserted)
    )
      THROW 50000, 'Order item does not belong to this customer', 1
  END

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 'workshop_participants_connections' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[workshop_participants_connections]
GO

CREATE TRIGGER [dbo].[workshop_participants_connections]
  ON [dbo].[workshop_participants]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS i LEFT OUTER JOIN workshops AS w ON w.id = i.workshop_id
              WHERE w.conference_day_id IS NULL)
      THROW 50000, 'Workshop not in database', 1
    IF EXISTS(SELECT *
              FROM inserted AS i LEFT OUTER JOIN conference_day_participants AS cdp
                  ON cdp.id = i.conference_day_participant_id
              WHERE cdp.participant_id IS NULL)
      THROW 50000, 'Conference day participant id not found', 1
    IF EXISTS(SELECT i.id
              FROM inserted AS i INNER JOIN workshops AS w ON w.id = i.workshop_id
                INNER JOIN conference_days AS cd ON cd.id = w.conference_day_id
              WHERE cd.id NOT IN (SELECT cdp.conference_day_id
                                  FROM inserted AS ist
                                    INNER JOIN conference_day_participants AS cdp
                                      ON cdp.id = ist.conference_day_participant_id))
      THROW 50000, 'Workshop does not belong to the conference day', 1
  END

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 't_customers_contact' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[t_customers_contact]
GO

CREATE TRIGGER [dbo].[t_customers_contact]
  ON [dbo].[customers]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted
              WHERE (phone IS NULL) AND (email IS NULL))
      THROW 50000, 'No contact with customer', 1
  END

IF EXISTS(SELECT *
          FROM sys.objects
          WHERE [name] = 't_conferences' AND TYPE = 'TR')
  DROP TRIGGER [dbo].[t_conferences]
GO

CREATE TRIGGER [dbo].[t_conferences]
  ON [dbo].[conferences]
  AFTER INSERT, UPDATE
AS
  BEGIN
    IF EXISTS(SELECT *
              FROM inserted AS i
              WHERE i.start_time > i.end_time)
      THROW 50000, 'Start date has to be earlier than end_date', 1
    IF EXISTS(SELECT *
              FROM inserted
              WHERE discount < 0)
      THROW 50000, 'Discount has to be equal or greater than 0', 1
  END

-- IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 't_payments_orders' AND TYPE = 'TR')
-- DROP TRIGGER [dbo].[t_payments_orders]
-- GO
--
-- CREATE TRIGGER [dbo].[t_payments_orders]
-- ON [dbo].[payments]
-- AFTER INSERT, UPDATE
-- AS BEGIN
--
-- END
--
-- IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 't_conference_day_participants' AND TYPE = 'TR')
-- DROP TRIGGER [dbo].[t_conference_day_participants]
-- GO
--
-- CREATE TRIGGER [dbo].[t_conference_day_participants]
-- ON [dbo].[conference_day_participants]
-- AFTER INSERT, UPDATE, DELETE
-- AS BEGIN
--
-- END

-- IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 't_customers_conference_day' AND TYPE = 'TR')
-- DROP TRIGGER [dbo].[t_customers_conference_day]
-- GO


-- DATA

-- EXEC add_customer 'Jan Kowalski','506256651','1234567890','test@gmail.com','street 1','zipcode','Cebuland',0
-- EXEC add_customer 'Władysław Kowalski','502256652','1234567890','test2@gmail.com','street 2','zipcode','Cebuland',0
-- EXEC add_customer 'Jan Woźniak','506506506',null,null,'street 3','zipcode','Poland',1
--
-- EXEC add_order '506256651',null
-- EXEC add_order null,'test2@gmail.com'
--
-- EXEC create_conference 'Piekna konferencja','2018-02-01','2018-02-03',0
-- EXEC create_conference 'Równie piekna konferencja','2018-01-21','2018-01-22',0.25
--
-- --SELECT * FROM conferences
-- exec add_conference_day 2,'2018-02-03',5
-- exec add_conference_day 2,'2018-02-01',1
-- exec add_conference_day 1,'2018-01-21',10
--
-- -- exec create_workshop 5,'sucza good workshop',5,0,'2018-01-23 10:00:00.000','2018-01-23 15:00:00.000'
-- --
-- -- exec create_workshop 9,'Even better workshop',1,0,'2018-01-23 10:00:00.000','2018-01-23 15:00:00.000'
--
-- exec create_workshop 11,'uber workshop',5,0,'2018-01-21 11:00','2018-01-21 12:00'
--
-- SELECT * FROM conference_days
-- SELECT * FROM workshops
-- SELECT * FROM orders
-- SELECT * FROM customers
-- SELECT * FROM order_items
--
-- exec add_order_item 1,1,5,5
-- exec add_order_item 1,5,11,5
-- exec add_order_item 5,5,11,0
--
-- exec add_participant 1,7,'Gienek'
-- exec add_participant 2,7,'Gienek 2'
--
-- SELECT * FROM participants
--
-- SELECT * FROM order_items