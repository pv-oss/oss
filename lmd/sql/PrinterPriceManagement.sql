#Datatbase for PPM
#Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
use lmd;

CREATE TABLE IF NOT EXISTS PrintingPrice (
      Id int(11) unsigned NOT NULL auto_increment,
      Printer varchar(128) NOT NULL,
      RecordType ENUM('Page','Job') NOT NULL,
      Price decimal(12,2) unsigned NOT NULL,
      PRIMARY KEY  (Id),
      KEY Printer (Printer),
      KEY RecordType (RecordType)
);

CREATE TABLE IF NOT EXISTS PrintingLog (
      Id int(11) unsigned NOT NULL auto_increment,
      Printer varchar(128) NOT NULL,
      User varchar(128) NOT NULL,
      JobId int(5) unsigned NOT NULL,
      DateTime varchar(128) NOT NULL,
      PageNumber int(5) unsigned NOT NULL,
      NumCopies int(5) unsigned NOT NULL,
      JobBilling varchar(128) NOT NULL,
      JobOriginatingHostName varchar(128) NOT NULL,
      JobName varchar(128) NOT NULL,
      Media varchar(128) NOT NULL,
      Sides varchar(128) NOT NULL,
      RecordType varchar(128) NOT NULL,
      PaymentId int(11) NOT NULL,
      Price float unsigned NOT NULL,
      PRIMARY KEY  (Id)
);

CREATE TABLE IF NOT EXISTS PrintingPayment (
      Id int(10) unsigned NOT NULL auto_increment,
      InvoiceNumber varchar(14) NOT NULL,
      User varchar(128) NOT NULL,
      DateOfPayment DATETIME NOT NULL,
      PaymentSum float unsigned NOT NULL,
      PRIMARY KEY  (Id)
);

CREATE TABLE IF NOT EXISTS UsersData (
      Id int(10) unsigned NOT NULL auto_increment,
      UserUID varchar(14) NOT NULL,
      UserName varchar(128) NOT NULL,
      Telaphone varchar(128) NOT NULL,
      Location varchar(128) NOT NULL,
      PostalCode varchar(128) NOT NULL,
      Street varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
);
