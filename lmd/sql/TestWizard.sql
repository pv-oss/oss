#Datatbase for PPM
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
use lmd;

CREATE TABLE IF NOT EXISTS  `TestWizard` (
      `Id` int(11) unsigned NOT NULL auto_increment,
      `TestName` varchar(128) NOT NULL,
      `ExaminerTeacher` varchar(128) NOT NULL,
      `TestRoom` varchar(128) NOT NULL,
      `TestDir` varchar(128) NOT NULL,
      `CurrentStep` varchar(128) NOT NULL,
      `StartTime` DATETIME NOT NULL,
      `EndTime` DATETIME NOT NULL,
      `WindowsAccess` int(1) NOT NULL,
      `ProxyAccess` int(1) NOT NULL,
      `DirectInternetAccess` int(1) NOT NULL,
      PRIMARY KEY  (Id)
);

CREATE TABLE IF NOT EXISTS TestWizardFiles (
      Id int(11) unsigned NOT NULL auto_increment,
      TestId int(11) unsigned NOT NULL,
      GetOrPost varchar(128) NOT NULL,
      User varchar(256) NOT NULL,
      File varchar(256) NOT NULL,
      DateTime DATETIME NOT NULL,
      PRIMARY KEY  (Id)
);

CREATE TABLE IF NOT EXISTS TestWizardUsers (
      Id int(10) unsigned NOT NULL auto_increment,
      TestId int(11) unsigned NOT NULL,
      PcName varchar(14) NOT NULL,
      UserUID varchar(128) NOT NULL,
      UserName varchar(128) NOT NULL,
      Student varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
);

