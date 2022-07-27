CREATE TABLE [Membership] (
  [MembershipID] INT,
  [Duration] INT,
  [Price] INT,
  [Status] BOOLEAN,
  [Type] nvarchar (255) NOT NULL CHECK ([Type] IN('Standard', 'Premium', 'Executive')) DEFAULT 'Standard',
  PRIMARY KEY ([MembershipID])
);

CREATE TABLE [Rental Location] (
  [RentalLocationID] INT,
  [MaxCapacity] INT,
  [CurrentCapacity] INT,
  [StreetName] VARCHAR,
  [City] VARCHAR,
  [State] VARCHAR,
  [Zipcode] INT,
  PRIMARY KEY ([RentalLocationID])
);

CREATE TABLE [Car Tier] (
  [CarTierID] INT,
  [TierName] CHAR,
  [PricePerHour] FLOAT,
  [BasicInsurance] FLOAT,
  [PricePerMile] FLOAT,
  [CollisionCoverage] FLOAT,
  [BodyCoverage] FLOAT,
  [MedicalCoverage] FLOAT,
  PRIMARY KEY ([CarTierID])
);

CREATE TABLE [Vendor] (
  [VendorID] INT,
  [Name] VARCHAR,
  [isVerified] BOOLEAN,
  PRIMARY KEY ([VendorID])
);

CREATE TABLE [Car] (
  [Model] CHAR,
  [Make] CHAR,
  [Color] CHAR,
  [CarTierID] INT,
  [ManufacturingYear] INT,
  [SeatCapacity] INT,
  [InsuranceStatus] ENUM,
  [CarType] ENUM,
  [isAvailability] BOOLEAN,
  [RegistrationNumber] INT,
  [DisableFriendly] BOOLEAN,
  [RentalLocationID] INT,
  [MeterRating] INT,
  [CarID] INT,
  [VendorID] INT,
  PRIMARY KEY ([CarID]),
  CONSTRAINT [FK_Car.ManufacturingYear]
    FOREIGN KEY ([ManufacturingYear])
      REFERENCES [Rental Location]([City]),
  CONSTRAINT [FK_Car.isAvailability]
    FOREIGN KEY ([isAvailability])
      REFERENCES [Car Tier]([BasicInsurance]),
  CONSTRAINT [FK_Car.VendorID]
    FOREIGN KEY ([VendorID])
      REFERENCES [Vendor]([isVerified])
);

CREATE TABLE [Car maintenance] (
  [MaintenanceID] INT,
  [DueDate] DATETIME,
  [ServiceDate] DATETIME,
  [DueMiles] FLOAT,
  [CarID] INT,
  PRIMARY KEY ([MaintenanceID]),
  CONSTRAINT [FK_Car maintenance.CarID]
    FOREIGN KEY ([CarID])
      REFERENCES [Car]([VendorID])
);

CREATE TABLE [Customer] (
  [CustomerID] INT,
  [FirstName] VARCHAR,
  [MiddleName] VARCHAR,
  [LastName] VARCHAR,
  [Age] INT,
  [StreetName] VARCHAR,
  [State] VARCHAR,
  [ZipCode] INT,
  [EmailID] VARCHAR,
  [PhoneNumber] INT,
  [DateOfBirth] DATE,
  [LicenseNumber] INT,
  [LicenseExpiry] DATE,
  [IsVerified] BOOLEAN,
  [UserId] INT,
  PRIMARY KEY ([CustomerID])
);

CREATE TABLE [Bookings] (
  [BookingID] INT,
  [CustomerID] INT,
  [Status] ENUM,
  [BookingStartTime] DATETIME,
  [BookingEndTime] DATETIME,
  [MeterStart ] INT,
  [MeterEnd] INT,
  [RentalAmount] FLOAT,
  [Penalty] FLOAT,
  [PaymentId] INT,
  [CarID] INT,
  [ActualStartTime] DATETIME,
  [ActualEndTime] DATETIME,
  [BookingRating] INTEGER,
  PRIMARY KEY ([BookingID]),
  CONSTRAINT [FK_Bookings.MeterStart ]
    FOREIGN KEY ([MeterStart ])
      REFERENCES [Customer]([UserId])
);

CREATE TABLE [Card Details] (
  [CardNumber] INT,
  [NameOnCard] VARCHAR,
  [ExpiryDate] DATETIME,
  [PaymentMethod] ENUM,
  [CVV] INT,
  [CustomerId] INT,
  [CardID] INT,
  [ IsPrimary] BOOLEAN,
  [CustomerID] INT,
  PRIMARY KEY ([CardID])
);

CREATE TABLE [Employees] (
  [EmployeeID] INT,
  [FirstName] VARCHAR,
  [MiddleName] VARCHAR,
  [LastName] VARCHAR,
  [Designation] VARCHAR,
  [EmailID] VARCHAR,
  PRIMARY KEY ([EmployeeID])
);

CREATE TABLE [Customer Membership] (
  [CustomerMembershipID] INT,
  [StartDate] DATETIME,
  [EndDate] DATETIME,
  [isactive] BOOLEAN,
  [MembershipCost] INT,
  [CustomerID] INT,
  [MembershipID] INT,
  PRIMARY KEY ([CustomerMembershipID]),
  CONSTRAINT [FK_Customer Membership.EndDate]
    FOREIGN KEY ([EndDate])
      REFERENCES [Membership]([Price])
);

CREATE TABLE [Customer Service] (
  [ServiceID] INT,
  [ComplaintStatus] ENUM,
  [Rating] INT,
  [IssueTitle] VARCHAR,
  [IssueDescription] VARCHAR,
  [CreatedTime] DATETIME,
  [CloseTime] DATETIME,
  [BookingId] INT,
  [EmployeeId] INT,
  PRIMARY KEY ([ServiceID]),
  CONSTRAINT [FK_Customer Service.EmployeeId]
    FOREIGN KEY ([EmployeeId])
      REFERENCES [Bookings]([Penalty])
);

CREATE TABLE [VendorTransactions] (
  [VendorID] INT,
  [VendorTransactionID] INT,
  [TransactionTime] DATETIME,
  [CarID] INT,
  [TransactionValue] FLOAT,
  PRIMARY KEY ([VendorTransactionID])
);

CREATE TABLE [Payment] (
  [PaymentID] INT,
  [CardID] INT,
  [BillingAmount] FLOAT,
  [ProcessedAt] DATETIME,
  [PaymentStatus] ENUM,
  PRIMARY KEY ([PaymentID])
);

CREATE TABLE [UserAuth] (
  [UserId] INT,
  [Username] VARCHAR,
  [Password] VARCHAR,
  [CreatedAt] DATETIME,
  [UpdatedAt] DATETIME,
  PRIMARY KEY ([UserId])
);

