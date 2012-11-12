#Datatbase for PPM
use lmd;

DROP TABLE IF EXISTS `OSSInv_PC`;
CREATE TABLE  OSSInv_PC(
      Id int(11) unsigned NOT NULL auto_increment,
      PC_Name varchar(128) NOT NULL,
      DateCollection DATETIME NOT NULL,
      MacAddress varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
);

DROP TABLE IF EXISTS `OSSInv_PC_Component`;
CREATE TABLE  OSSInv_PC_Component(
      Id int(11) unsigned NOT NULL auto_increment,
      PC_Id int(11) unsigned NOT NULL,
      PC_Component_Name varchar(128) NOT NULL,
      SubComponent varchar(128) NOT NULL,
      Component_Name varchar(128) NOT NULL,
      Component_Value varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
);

DROP TABLE IF EXISTS `OSSInv_PC_Component_Parameter`;
CREATE TABLE  OSSInv_PC_Component_Parameter(
      Id int(11) unsigned NOT NULL auto_increment,
      PC_Component_Id int(11) unsigned NOT NULL,
      Component_Parameter_Name varchar(128) NOT NULL,
      Component_Parameter_Value varchar(256) NOT NULL,
      PRIMARY KEY  (Id)
);

DROP TABLE IF EXISTS `OSSInv_PC_Info`;
CREATE TABLE  OSSInv_PC_Info(
      Id int(11) unsigned NOT NULL auto_increment,
      PC_Name varchar(128) NOT NULL,
      Info_Category_Id int(11) unsigned NOT NULL,
      Value varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `OSSInv_PC_Info_Category`;
CREATE TABLE  OSSInv_PC_Info_Category(
      Id int(11) unsigned NOT NULL auto_increment,
      Category_Name varchar(128) NOT NULL,
      Category_Label varchar(128) NOT NULL,     
      Category_Type varchar(128) NOT NULL,
      PRIMARY KEY  (Id)
);

INSERT INTO `OSSInv_PC_Info_Category` (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, "Inventary_Number", "Inventarnummer", "Text" );
INSERT INTO `OSSInv_PC_Info_Category` (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, "Warranty", "Garantie bis", "Date" );
INSERT INTO `OSSInv_PC_Info_Category` (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, "BuyDate", "Kaufdatum", "Date" );
INSERT INTO `OSSInv_PC_Info_Category` (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, "Manufacturer", "Hersteller", "Text" );
INSERT INTO `OSSInv_PC_Info_Category` (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, "Model", "Modell", "Text" );
