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
- K1 + E3: Change the length
- K2: toggle mute
- K3: play/stop the sequence
- K1 + K2: clear visible
- K1 + K3: clear all

fun things: goto `TRACK X` and randomize with `randomize` parameter and have it evolve with `evolve` parameter.

the supercollider engine uses `mx.samples` which you can optionally install:

```shell
;install https://github.com/schollz/mx.samples
```

and, once installed, download any sound packs you want which you can then use with pitter-patter.

## grid controls

### note mode

the last row of the grid is a keyboard.

hold the last row, last column of the grid to shift to the next octave (and aligns the octave).

all the other buttons enter in notes (press and hold two to create ranges).

press the last row, last column to enter "sequencer" mode.

### sequence mode

use the bottom row to select a sequence.

use the other rows to create a sequence.

press the last row, last column to enter "note" mode.

## install

you can install through maiden:

```
;install https://github.com/schollz/pitter-patter
```
