=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 ossBaseTranslations

=head1 PREFACE

 This package contains basic translatons for the OSS.

=head1 SYNOPSIS

=over 2

=cut

require Exporter;
package ossBaseTranslations;
use strict;

use vars qw(    @ISA
                @EXPORT
		$Translations
		$LangMap
);

@ISA = qw(Exporter);

@EXPORT = qw(
		$Translations
		$LangMap
);

# -- Maps
$Translations = {
                     "ES" =>  { "classname"     => "Class",
                               "teachers"       => "Teachers",
                               "students"       => "Students",
                               "administration" => "Administration",
                               "templates"      => "Template Users",
                               "rooms"          => "Rooms",
                               "admin"          => "Main System Administrator",
                               "my_pictures"    => "My Pictures",
                               "my_music"       => "My Music",
                               "tworkstations"  => "Default Profil for Workstation User",
                               "tstudents"      => "Default Profil for Student",
                               "tteachers"      => "Default Profil for Teachers",
                               "tadministration"=> "Default Profil for Administration"
                             },
                     "FR" => { "classname"      => "Classe",
                               "teachers"       => "Enseignants",
                               "teacher"        => "Enseignant",
                               "students"       => "Élèves",
                               "administration" => "Administration",
                               "templates"      => "Template Utilisateur",
                               "rooms"          => "Salles",
                               "admin"          => "Main System Administrator",
                               "my_pictures"    => "Mes Images",
                               "my_music"       => "Ma Musique",
                               "tworkstations"  => "Default Profil pur Workstation-Utlisateur",
                               "tstudents"      => "Default Profil pur Élève",
                               "tteachers"      => "Default Profil pur Enseignant",
                               "tadministration"=> "Default Profil pur Administration"
                             },
                     "IT" =>  { "classname"     => "Class",
                               "teachers"       => "Teachers",
                               "students"       => "Students",
                               "administration" => "Administration",
                               "templates"      => "Template Users",
                               "rooms"          => "Rooms",
                               "admin"          => "Main System Administrator",
                               "my_pictures"    => "My Pictures",
                               "my_music"       => "My Music",
                               "tworkstations"  => "Default Profil for Workstation User",
                               "tstudents"      => "Default Profil for Student",
                               "tteachers"      => "Default Profil for Teachers",
                               "tadministration"=> "Default Profil for Administration"
                             },
                     "CZ" =>  { "classname"     => "Class",
                               "teachers"       => "Teachers",
                               "students"       => "Students",
                               "administration" => "Administration",
                               "templates"      => "Template Users",
                               "rooms"          => "Rooms",
                               "my_pictures"    => "My Pictures",
                               "my_music"       => "My Music",
                               "admin"          => "Main System Administrator",
                               "tworkstations"  => "Default Profil for Workstation User",
                               "tstudents"      => "Default Profil for Student",
                               "tteachers"      => "Default Profil for Teachers",
                               "tadministration"=> "Default Profil for Administration"
                             },
                     "EN" =>  { "classname"     => "Class",
                               "teachers"       => "Teachers",
                               "students"       => "Students",
                               "administration" => "Administration",
                               "templates"      => "Template Users",
                               "rooms"          => "Rooms",
                               "my_pictures"    => "My Pictures",
                               "my_music"       => "My Music",
                               "admin"          => "Main System Administrator",
                               "tworkstations"  => "Default Profil for Workstation User",
                               "tstudents"      => "Default Profil for Student",
                               "tteachers"      => "Default Profil for Teachers",
                               "tadministration"=> "Default Profil for Administration"
                             },
                     "DE" =>  { "classname"     => "Klasse",
                               "teachers"       => "Lehrer",
                               "students"       => "Schüler",
                               "administration" => "Verwaltung",
                               "templates"      => "Template Benutzer",
                               "rooms"          => "Räume",
                               "my_pictures"    => "Eigene Bilder",
                               "my_music"       => "Eigene Musik",
                               "admin"          => "System Administrator",
                               "tworkstations"  => "Default Profil für Workstationbenutzer",
                               "tstudents"      => "Default Profil für Schüler",
                               "tteachers"      => "Default Profil für Lehrer",
                               "tadministration"=> "Default Profil für Verwaltung"
                             },
                     "HU" =>  { "classname"     => "Osztály",
                               "teachers"       => "Tanárok",
                               "students"       => "Diákok",
                               "administration" => "Adminisztráció",
                               "templates"      => "Template Felhasználó",
                               "rooms"          => "Termek",
                               "my_pictures"    => "My Pictures",
                               "my_music"       => "My Music",
                               "admin"          => "Renszergazda",
                               "tworkstations"  => "Default Profil dolgozatírásra",
                               "tstudents"      => "Default profil diákoknak",
                               "tteachers"      => "Default profil tanároknak",
                               "tadministration"=> "Default profil adminisztrációnak"
                            }

                   };

$LangMap    = {
                  "EN" => "EN",
                  "US" => "EN",
                  "AU" => "EN",
                  "DE" => "DE",
                  "AT" => "DE",
                  "CH" => "DE",
                  "RO" => "RO",
                  "HU" => "HU",
                  "IT" => "IT",
                  "ES" => "ES",
                  "FR" => "FR",
                  "CZ" => "CZ"
                };

