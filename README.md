# VMware Guest OS Disk Space Monitor

Monitors VMware guest OS disk space and triggers an Opsgenie alert when the available free space falls below the defined threshold

## Requirements

- [Powershell](https://docs.microsoft.com/en-us/powershell/)
- [VMware.PowerCLI](https://www.powershellgallery.com/packages/VMware.PowerCLI)
- [PsIni](https://www.powershellgallery.com/packages/PsIni/3.1.2)
- [PSWriteHTML](https://www.powershellgallery.com/packages/PSWriteHTML)
- [Posh-Syslog](https://www.powershellgallery.com/packages/Posh-SYSLOG)
- [Chocolatey](https://chocolatey.org/)
- [NSSM](https://nssm.cc/download)

## Installation

- Download code from GitHub
    - _Note:  If you don't have Git installed you can also just grab the zip:  https://github.com/CC-Digital-Innovation/vmware_guest_diskspace_mon/archive/master.zip_

    ```sh
    git clone https://github.com/CC-Digital-Innovation/vmware_guest_diskspace_mon.git
    ```

- Copy config.ini.example to config.ini
- Update settings in config.ini file.

## Usage

- Install Requirements from Powershell command prompt

    ```Powershell
    Start-Process Powershell -Verb RunAs
    Set-ExecutionPolicy -Confirm:$false Unrestricted -Force
    Get-ExecutionPolicy
    Install-Module -Confirm:$false -Name PsIni
    .\requirements.ps1
    ```

- From Powershell command prompt

    ```Powershell
    .\check_diskspace.ps1
    ```

- Install as Windows service using nssm_helper.ps1

    _Note: Be sure to update the NSSM sevicename and scriptpath in the config.ini_

    ```Powershell
    .\nssm_helper.ps1
    ```
    _Note:  You will need to update the service to run as a user with admin privledge._


- From Windows command prompt or from task scheduler

    _Note: Running as a service is preferred, if you want to run as a scheduled task, you will need to modify the code to remove the while loop. I may update this to happen automatically in a future release depending on a config.ini setting._
    ```Powershell
    start powershell "& "./check_diskspace.ps1"
    ```



## Compatibility

This is was built and tested on Windows 10 with Powershell Version 5.1.19041.1023, but most likely work on any Windows system with Powershell >= Version 2.

## Disclaimer

The code provided in this project is an open source example and should not be treated as an officially supported product. Use at your own risk. If you encounter any problems, please log an [issue](https://github.com/CC-Digital-Innovation/vmware_guest_diskspace_mon/issues).

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request ツ

## History

- See [CHANGELOG.md](https://github.com/CC-Digital-Innovation/vmware_guest_diskspace_mon/blob/main/CHANGELOG.md)

## Credits

Rich Bocchinfuso <<rbocchinfuso@gmail.com>>

## License

MIT License

Copyright (c) [2021] [Richard J. Bocchinfuso]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
