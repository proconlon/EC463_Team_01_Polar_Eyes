James

The raspberry pi 4 is tentatively going to be for RAID only. The images will be passed here via ethernet from the Pi zero 2W.

The pi 4 will be on intermittently only (currently estimaging every 30min) until all images have been transferred and then shutdown clean.

Thus the build for the OS must be fast booting and shutdown as soon as possible.


# GitHub Actions 

Must run:
```
sudo modprobe loop
```

When run with Act locally, the built file is located at 

```sh
./build/polar-eyes-worker-v...img
```