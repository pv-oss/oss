# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
DROP DATABASE IF EXISTS `lmd`;
CREATE DATABASE `lmd` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
use lmd;
DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
  `id`           varchar(128) NOT NULL,
  `dn`           varchar(128) NOT NULL,
  `sdn`          varchar(128) default NULL,
  `username`     varchar(128) default NULL,
  `userpassword` varchar(2048) default NULL,
  `role`         varchar(128) default NULL,
  `ip`           varchar(128) default NULL,
  `room`         varchar(128) default NULL,
  `logintime`    bigint(20)   default NULL,
  `logoff`       bigint(20)   default 0,
  `lastaction`   bigint(20)   default NULL,
  `lang`         char(2)      default 'EN',
  `datas`        mediumblob   default NULL,
  PRIMARY KEY  (`id`)
);

DROP TABLE IF EXISTS `sessiondata`;
CREATE TABLE `sessiondata` (
  `id`         varchar(128)  NOT NULL,
  `variable`   varchar(128)  NOT NULL,
  `value`      mediumblob    default NULL,
  PRIMARY KEY  (`id`,`variable` )
);

DROP TABLE IF EXISTS `lang`;
CREATE TABLE `lang` (
  `lang`       char(5)       default 'EN',
  `section`    varchar(30)   default 'GLOBAL',
  `string`     varchar(240)  default  '',
  `value`      varchar(1024) default NULL,
  PRIMARY KEY  (`lang`,`section`,`string` )
);

CREATE TABLE IF NOT EXISTS `missedlang` (
  `lang`       char(5)      default 'EN',
  `section`    varchar(30)  default 'GLOBAL',
  `string`     varchar(240) default  '',
  `value`      varchar(1024) default NULL,
  PRIMARY KEY  (`lang`,`section`,`string` )
);

CREATE TABLE IF NOT EXISTS `history` (
  `time`         bigint(20)   default NULL,
  `username`     varchar(128) NOT NULL,
  `room`         varchar(128) default NULL,
  `application`  varchar(128) NOT NULL,
  `action`       varchar(128) NOT NULL,
  `request`      mediumblob   default NULL,
  PRIMARY KEY  (`time`,`username`)
);

CREATE TABLE IF NOT EXISTS `acls` (
  `type`        char(1)      default 'r',
  `owner`       varchar(128) NOT NULL,
  `destination` varchar(128) NOT NULL,
  `right`       char(1)      NOT NULL,
  PRIMARY KEY  (`type`,`owner`,`destination`)
);
INSERT INTO `acls` VALUES ('r','teachers','ManageRooms','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.c','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.group','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.role','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.admin','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.description','n');
INSERT INTO `acls` VALUES ('r','*','ManageYourself.default.rasaccess','n');

