# pitter-patter

press and make quantized patterns of sequence across four tracks, using a grid or a midi controller.

![image](https://repository-images.githubusercontent.com/865110977/47cb53b1-eb3e-4ee1-98e8-f748a441c9b4)


## requirements

- norns (version 231114+) 
- grid OR midi controller

## documentation

- E1: Change the sequence
- E2: Change the direction of the sequence
- E3: Change the note pool
- K1 + E1: Change the instrument
- K1 + E2: Change the clock division
- K1 + K3: Change the velocity style
- K2: n/a
- K3: Play/stop the sequence

the supercollider engine uses `mx.samples` which you can optionally install:

```shell
;install https://github.com/schollz/mx.samples
```

and, once installed, download any sound packs you want which you can then use with pitter-patter.

### grid controls

the last row of the grid is a keyboard.

the last row, last column of the grid shifts to the next octave (and aligns the octave).

all the other buttons enter in notes (press and hold two to create ranges).

## install

you can install through maiden:

```
;install https://github.com/schollz/pitter-patter
```
