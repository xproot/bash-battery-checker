# bash-battery-checker
Simple script I made to check battery capacity which I keep touching every so often
![image](https://github.com/user-attachments/assets/d137ae74-530c-4ef5-9938-19b9951a6da8)
## Requirements
- Bash (specific version unknown)
- ncurses (`tput`)
- Coreutils (`cat`, `printf`, `tr`)
- grep
## Usage
`battery.sh [options] [battery...]`

If you run the script without any arguments, it will print a summarized overview of all the batteries it can find

![image](https://github.com/user-attachments/assets/f46620a1-b426-4314-b35b-f5f858bcd938)
### Options
#### --no-color
Disables all ANSI escape codes, useful for piping the output through various programs

![image](https://github.com/user-attachments/assets/0277894e-97b9-441f-a4c3-dcd2807510d7)
#### --color
Force enable ANSI escape codes, this is in case the script believes you are running a color incapable terminal.
#### --text-only
This will disable color and progress bars.

![image](https://github.com/user-attachments/assets/7b44cc5c-f71e-457e-94d1-9d1a3cd5d39a)
#### --detailed
This will show additional battery information if it is present, Name, Technology, Capacity and Health (in Wh and/or Ah, cycles), Power (Volts, Amps, Watts)

![image](https://github.com/user-attachments/assets/158df774-6f14-46c7-9fef-d3489212f8c9)
![image](https://github.com/user-attachments/assets/0b00a7af-16a1-4d2a-bff8-6096ef2ef87e)


#### --help
```
Usage: battery.sh [options] [battery...]

Options:
  --no-color       Disable colored output
  --color          Force enable colored output
  --text-only      Display information in plain text only
  --detailed       Show detailed battery information
  --help           Show this help message
  --watch          Watch for changes and update information
  --width <width>  Set width for progress bars (ignored in text-only mode)

If no batteries are specified, all available batteries will be shown.
```
#### --watch
Continously clear the screen and run the script. Please use `watch -c battery` instead.
#### --width <width>
Forcibly set the width (of the presumed window size) for the progress bar size. Useful for terminals that do not expose the width information.
### [battery...]
If you have one specific battery you wish to see, you can specify it here using the device filename `/sys/class/power_supply/BAT*`

![image](https://github.com/user-attachments/assets/e71f12db-52bb-4e71-8514-8b18e4be8314)

Power Supplies other than `Battery` are not supported, but for amusement, here is `Mains` type AC.

![image](https://github.com/user-attachments/assets/4ebddf03-224f-4ee3-8c4f-6b0dde9e207e)

## FAQ
- **Q: Why does this look like it was written by a mad man?**
- A: Because it was. I originally made ChatGPT write a basic script for checking the battery and I kept on adding features to it, this is the result.

