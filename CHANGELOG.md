<!-- markdownlint-disable MD001 MD009 MD012 MD024 MD032-->

# Changelog

## [Unreleased]

- TODO


## [0.4.0] - 2021-07-01

### Added

- Cycle time and loop to prepare for service creation
- nssm-helper.ps1 to simplify service creation


## [0.3.0] - 2021-06-30

### Added

- Code to parse responders and tags from config.ini and place into array to properly pass Opsgenie body JSON payload
- Syslog function


### Fixed

- Parsing responders and tags and properly constructing the array


## [0.2.0] - 2021-06-29

### Added

- config.ini file for all configuration parameters


### Security

- Removed sensative config info from code and put into config.ini
- Added config.ini.example and updated .gitignore to exclude .ini from commits

## [0.1.0] - 2021-06-29

### Added

- Pulling and comparing VM guest OS disk space to threshold
- Opsgenie function to sent alert to Opsgenie when disk space falls below the defined threshold
