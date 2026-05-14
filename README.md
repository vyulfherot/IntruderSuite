# Intruder Suite
### A collection of PowerShell penetration testing tools for Windows.
Uses simple Win32 api methods and bytecode manipulation.
All modules and classes can be loaded into powershell by invoking:
- `Import-Module ".\Suite.psm1" -Force`

### Dislaimer:
This was a simple, experimental and educational attempt at codecave and process injection to learn more about the Win32 api, PE files, Assembly and PIC shellcode.
Don't take this as a serious or advanced project. This was for learning and fun purposes only.

I will not provide proper documentation unless highly demanded.

Because of the said nature of this project it will likely receive very few updates, if any, then be abandoned, as it's served it's purpose. 
Anyone is free to make their own "altered" or "upgraded" versions if desire be.

# Main
## Vermine
Able to inject specified PIC shellcode into free codecave space within a Portable Executable file (.exe).

## Progenitor
Able to inject DLL, PIC shellcode and PE bytecode (maybe coming soon) into running processes.

## New-RunShellcode
Generates CreateProcessA PIC shellcode to invoke whatever you specify. Recommended to use for supplying Vermine and Progenitor with PIC shellcode.

## Cavediver
Calculates the amount of free null bytes at the end of the `.text` section of the specified PE file or directory of PE files.
