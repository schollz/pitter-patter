MxSamplez {

	var server;
	var maxSamples;

	var <ins;

	var synFx;
	var busDelay;
	var busReverb;
	var busOut;
	var garbageCollector;

	*new {
		arg serverName,numberMaxSamples,argBusOut;
		^super.new.init(serverName,numberMaxSamples,argBusOut);
	}

	init {
		arg serverName,numberMaxSamples,argBusOut;
		busOut=argBusOut;
		server=serverName;
		maxSamples=numberMaxSamples;
		ins=Dictionary.new();

		SynthDef("mxfx",{
			arg inDelay, inReverb, reverb=0.05, out, secondsPerBeat=0.2,delayBeats=4,delayFeedback=0.1,bufnumDelay;
			var snd,snd2,y,z;

			// delay
			snd = In.ar(inDelay,2);
			snd = CombC.ar(
				snd,
				2,
				secondsPerBeat*delayBeats,
				secondsPerBeat*delayBeats*LinLin.kr(delayFeedback,0,1,2,128),// delayFeedback should vary between 2 and 128
			);
			Out.ar(out,snd);

			// reverb
			snd2 = In.ar(inReverb,2);
			snd2 = DelayN.ar(snd2, 0.03, 0.03);
			snd2 = CombN.ar(snd2, 0.1, {Rand(0.01,0.099)}!32, 4);
			snd2 = SplayAz.ar(2, snd2);
			snd2 = LPF.ar(snd2, 1500);
			5.do{snd2 = AllpassN.ar(snd2, 0.1, {Rand(0.01,0.099)}!2, 3)};
			snd2 = LPF.ar(snd2, 1500);
			snd2 = LeakDC.ar(snd2);
			Out.ar(out,snd2);
		}).send(server);

		busDelay = Bus.audio(server,2);
		busReverb = Bus.audio(server,2);
		server.sync;
		synFx = Synth.tail(server,"mxfx",[\out,0,\inDelay,busDelay,\inReverb,busReverb]);

		// unload old buffers periodically
		garbageCollector=Routine {
			loop {
				var diskMB=0.0;
				ins.keysValuesDo({arg k1, val;
					val.buf.keysValuesDo({arg k,v;
						diskMB=diskMB+(v.numFrames*v.numChannels*4.0/1000000.0);
					});
				});
				if (diskMB>100.0,{
					("current mb usage: "++diskMB).postln;
					ins.keysValuesDo({arg k, val;
						val.garbageCollect;
					});	
					1.wait;
				},{
					3.wait;
				});
			}
		}.play;
	}

	setParam {
		arg folder,key,value;
		if (ins.at(folder).isNil,{
			ins.put(folder,MxSamplezInstrument(server,folder,maxSamples,busOut,busDelay.index,busReverb.index));
		});
		ins.at(folder).setParam(key,value);
	}

	noteOn {
		arg folder,note,velocity;
		if (ins.at(folder).isNil,{
			ins.put(folder,MxSamplezInstrument(server,folder,maxSamples,busOut,busDelay.index,busReverb.index));
		});
		["note_on",folder,note,velocity].postln;
		ins.at(folder).noteOn(note,velocity);
	}

	setSustain {
		arg folder, on;
		if (ins.at(folder).isNil,{
			ins.put(folder,MxSamplezInstrument(server,folder,maxSamples,busOut,busDelay.index,busReverb.index));
		});
		ins.at(folder).sustain(on);
	}

	setSustenuto {
		arg folder, on;
		if (ins.at(folder).isNil,{
			ins.put(folder,MxSamplezInstrument(server,folder,maxSamples,busOut,busDelay.index,busReverb.index));
		});
		ins.at(folder).sostenuto(on);
	}

	noteOnFX {
		arg folder,note,velocity,
		amp,pan,
		attack,decay,sustain,release,
		delaysend,reverbsend,
		lpf,lpfrq,hpf,hpfrq;
		if (ins.at(folder).isNil,{
			ins.put(folder,MxSamplezInstrument(server,folder,maxSamples,busOut,busDelay.index,busReverb.index));
		});
		ins.at(folder).noteOnFX(note,velocity,amp,pan,attack,decay,sustain,release,delaysend,reverbsend,lpf,lpfrq,hpf,hpfrq);
	}

	noteOff {
		arg folder,note;
		if (ins.at(folder).notNil,{
			ins.at(folder).noteOff(note);
			["note_off",folder,note].postln;
		});
	}

	free {
		garbageCollector.stop;
		ins.keysValuesDo({ arg note, val;
			val.free;
		});
		synFx.free;
		busDelay.free;
		busReverb.free;
		ins.free;
	}

}
