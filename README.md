~~~
  ____    _           _          _   
 |  _ \  (_)   __ _  | |   ___  | |_ 
 | |_) | | |  / _` | | |  / _ \ | __|
 |  __/  | | | (_| | | | |  __/ | |_ 
 |_|     |_|  \__, | |_|  \___|  \__|
              |___/                  
~~~

PowerShell implementation of the popular [Figlet](http://www.figlet.org/) command line utility. This is written with the intention of being 100% compatible with existing Figlet fonts. The default set of fonts has been included here, with many more available.

## Examples

Basic usage:
~~~
PS C:\> Piglet "Hello, world!"
  _   _          _   _                                           _       _   _ 
 | | | |   ___  | | | |   ___         __      __   ___    _ __  | |   __| | | |
 | |_| |  / _ \ | | | |  / _ \        \ \ /\ / /  / _ \  | '__| | |  / _` | | |
 |  _  | |  __/ | | | | | (_) |  _     \ V  V /  | (_) | | |    | | | (_| | |_|
 |_| |_|  \___| |_| |_|  \___/  ( )     \_/\_/    \___/  |_|    |_|  \__,_| (_)
                                |/                                             
~~~

Specify font:
~~~
PS C:\> Piglet "Hello, world!" -Font "script"
  ,            _    _                                    _           
 /|   |       | |  | |                                  | |     |   |
  |___|   _   | |  | |   __                 __    ,_    | |   __|   |
  |   |\ |/   |/   |/   /  \_     |  |  |_ /  \_ /  |   |/   /  |   |
  |   |/ |__/ |__/ |__/ \__/  o    \/ \/   \__/     |_/ |__/ \_/|_/ o
                              /                                      
~~~

You can also pipe output from another command into Piglet:
~~~
PS C:\> Get-Date -Format "MM/dd/yyyy" | Piglet
 _   _      __   ___    ____       __  ____     ___    ____     ___  
/ | / |    / /  / _ \  | ___|     / / |___ \   / _ \  |___ \   / _ \ 
| | | |   / /  | | | | |___ \    / /    __) | | | | |   __) | | | | |
| | | |  / /   | |_| |  ___) |  / /    / __/  | |_| |  / __/  | |_| |
|_| |_| /_/     \___/  |____/  /_/    |_____|  \___/  |_____|  \___/ 
~~~

## More info
* Font file format: http://www.jave.de/figlet/figfont.html
* Additional fonts: https://github.com/cmatsuoka/figlet-fonts
