MxSamplezInstrument {

	var server;

	var <folder;
	var maxSamples;

	var <noteNumbers;
	var <noteDynamics;
	var <noteRoundRobins;

	var <buf;
	var bufUsed;
	var <syn;
	var synOutput;
	var <params;

	var <busDelay;
	var <busReverb;
	var <busOut;
	var busOutput;

	var pedalSustainOn;
	var pedalSostenutoOn;
	var pedalSustainNotes;
	var pedalSostenutoNotes;
	var voicesOn;

	*new {
		arg serverName,folderToSamples,numberMaxSamples,busOutArg,busDelayArg,busReverbArg;
		^super.new.init(serverName,folderToSamples,numberMaxSamples,busOutArg,busDelayArg,busReverbArg);
	}

	init {
		arg serverName,folderToSamples,numberMaxSamples,busOutArg,busDelayArg,busReverbArg;

		server=serverName;
		folder=folderToSamples;
		maxSamples=numberMaxSamples;
		busDelay=busDelayArg;
		busReverb=busReverbArg;
		busOut=busOutArg;
		busOutput=Bus.audio(server,2);

		pedalSustainOn=false;
		pedalSostenutoOn=false;
		voicesOn=Dictionary.new();
		bufUsed=Dictionary.new();
		pedalSustainNotes=Dictionary.new();
		pedalSostenutoNotes=Dictionary.new();
		buf=Dictionary.new();
		syn=Dictionary.new();
		noteDynamics=Dictionary.new();
		noteRoundRobins=Dictionary.new();
		noteNumbers=Array.new(128);
		params = Dictionary.newFrom([
			"amp", 1.0,
			"pan", 0.0,
			"attack", 0.01,
			"decay", 0.1,
			"sustain", 1.0,
			"release", 5.0,
			"fadetime", 1.0,
			"delaysend",0.0,
			"reverbsend",0.0,
			"lpf",18000.0,
			"lpfrq",0.707,
			"hpf",60.0,
			"hpfrq",1.0,
		]);


		PathName.new(folder).entries.do({ arg v;
			var fileSplit=v.fileName.split($.);
			var note,dyn,dyns,rr,rel;
			if (fileSplit.last=="wav",{
				if (fileSplit.size==6,{
					note=fileSplit[0].asInteger;
					dyn=fileSplit[1].asInteger;
					dyns=fileSplit[2].asInteger;
					rr=fileSplit[3].asInteger;
					rel=fileSplit[4].asInteger;
					if (rel==0,{
						if (noteDynamics.at(note).isNil,{
							noteDynamics.put(note,dyns);
							noteNumbers.add(note);
						});
						if (noteRoundRobins.at(note.asString++"."++dyn.asString).isNil,{
							noteRoundRobins.put(note.asString++"."++dyn.asString,rr);
						},{
							if (rr>noteRoundRobins.at(note.asString++"."++dyn.asString),{
								noteRoundRobins.put(note.asString++"."++dyn.asString,rr);
							});
						});
					});
				});
			});
		});

		noteNumbers=noteNumbers.sort;


		// check if playx2 is available on the server
		if (SynthDescLib.global.at("playx2".asSymbol).isNil,{
			SynthDef("playx2",{
				arg out=0,pan=0,amp=1.0,
				buf1,buf2,buf1mix=1,
				t_trig=1,rate=1,
				attack=0.01,decay=0.1,sustain=1.0,release=0.2,gate=1,
				startPos=0;
				var snd,snd2;
				var frames1=BufFrames.ir(buf1);
				var frames2=BufFrames.ir(buf2);
				rate=rate*BufRateScale.ir(buf1);
				snd=PlayBuf.ar(2,buf1,rate,t_trig,startPos:startPos*frames1,doneAction:Select.kr(frames1>frames2,[0,2]));
				snd2=PlayBuf.ar(2,buf2,rate,t_trig,startPos:startPos*frames2,doneAction:Select.kr(frames2>frames1,[0,2]));
				snd=(buf1mix*snd)+((1-buf1mix)*snd2);//SelectX.ar(buf1mix,[snd2,snd]);
				snd=snd*EnvGen.ar(Env.adsr(attack,decay,sustain,release),gate+EnvGen.kr(Env.new([0,0,1],[10,0.1])),doneAction:2);
				DetectSilence.ar(snd,0.0005,doneAction:2);
				snd=Balance2.ar(snd[0],snd[1],pan,amp);
				snd=snd/4; // assume ~ 4 note polyphony so reduce max volume
				Out.ar(out,snd);
			}).send(server);

			SynthDef("playx1",{
				arg out=0,pan=0,amp=1.0,
				buf1,buf2,buf1mix=1,
				t_trig=1,rate=1,
				attack=0.01,decay=0.1,sustain=1.0,release=0.2,gate=1,
				startPos=0;
				var snd,snd2;
				var frames1=BufFrames.ir(buf1);
				var frames2=BufFrames.ir(buf2);
				rate=rate*BufRateScale.ir(buf1);
				snd=PlayBuf.ar(1,buf1,rate,t_trig,startPos:startPos*frames1,doneAction:Select.kr(frames1>frames2,[0,2]));
				snd2=PlayBuf.ar(1,buf2,rate,t_trig,startPos:startPos*frames2,doneAction:Select.kr(frames2>frames1,[0,2]));
				snd=SelectX.ar(buf1mix,[snd2,snd]);
				snd=snd*EnvGen.ar(Env.adsr(attack,decay,sustain,release),gate+EnvGen.kr(Env.new([0,0,1],[10,0.1])),doneAction:2);
				DetectSilence.ar(snd,0.001,doneAction:2);
				snd=Pan2.ar(snd,pan,amp);
				snd=snd/4; // assume ~ 4 note polyphony so reduce max volume
				Out.ar(out,snd);
			}).send(server);
		});




		synOutput = {
			arg out=0,in,
			lpf=18000,lpfrq=1.0,hpf=60,hpfrq=1.0,
			busReverb,busDelay,sendReverb=0,sendDelay=0;
			var snd=In.ar(in,2);
			snd = RLPF.ar(snd,lpf,lpfrq);
			snd = RHPF.ar(snd,hpf,hpfrq);
			Out.ar(out,snd);
			Out.ar(busReverb,snd*sendReverb);
			Out.ar(busDelay,snd*sendDelay);
		}.play(target:server, args:[\out,busOut, \in, busOutput.index,\busReverb,busReverb,\busDelay,busDelay],addAction:\addToHead);

	}


	garbageCollect {
		var ct=SystemClock.seconds;
		var bufUsedOrdered=Dictionary();
		var deleted=0;
		var files;
		bufUsed.keysValuesDo({ arg k,v;
			bufUsedOrdered[v]=k;
		});
		files=bufUsedOrdered.atAll(bufUsedOrdered.order);
		if (files.notNil,{
			files.reverse.do({arg k,i;
				if (deleted<10,{
					if (buf.at(k).notNil,{
						var bnum=buf.at(k).bufnum;
						var doRemove=false;
						if (bufUsed.at(k).notNil,{
							if (ct-bufUsed.at(k)>20,{
								doRemove=true;
							});
						});
						if (doRemove==true,{
							buf.at(k).free;
							buf.removeAt(k);
							bufUsed.removeAt(k);
							deleted=deleted+1;
							("unloaded buffer file "++k).postln;
						});
					});
				});
			});
		});

	}

	setParam {
		arg key,value;
		params.put(key,value);
		syn.keysValuesDo({arg note,v1;
			syn.at(note).keysValuesDo({ arg k,v;
				if (v.isRunning,{
					v.set(key,value);
				});
			});
		});
		this.updateOutput;
	}

	noteOnFX {
		arg note,velocity,
		amp,pan,
		attack,decay,sustain,release,
		delaysend,reverbsend,
		lpf,lpfrq,hpf,hpfrq;
		params.put("amp",amp);
		params.put("pan",pan);
		params.put("attack",attack);
		params.put("decay",decay);
		params.put("sustain",sustain);
		params.put("release",release);
		params.put("delaysend",delaysend);
		params.put("reverbsend",reverbsend);
		params.put("lpf",lpf);
		params.put("lpfrq",lpfrq);
		params.put("hpf",hpf);
		params.put("hpfrq",hpfrq);
		this.updateOutput;
		this.noteOn(note,velocity);
	}

	updateOutput {
		synOutput.set(
			\sendReverb,params.at("reverbsend"),
			\sendDelay,params.at("delaysend"),
			\hpf,params.at("hpf"),
			\hpfrq,params.at("hpfrq"),
			\lpf,params.at("lpf"),
			\lpfrq,params.at("lpfrq"),
		);
	}

	noteOn {
		arg note,velocity;
		var noteOriginal=note;
		var noteLoaded=note;
		var noteClosest=noteNumbers[noteNumbers.indexIn(note)];
		var noteClosestLoaded;
		var rate=1.0;
		var rateLoaded=1.0;
		var buf1mix=1.0;
		var amp=1.0;
		var file1,file2,fileLoaded;
		var velIndex=0;
		var velIndices;
		var vels;
		var dyns;
		var noteNumbersLoadedDict=Dictionary.new();
		var notNumbersLoaded=Array.new(128);

		buf.keysValuesDo({arg k,v;
			var fileSplit=k.split($.);
			var note=fileSplit[0];
			var dyn=fileSplit[1];
			noteNumbersLoadedDict.put((note++"."++dyn).asFloat,k);
			notNumbersLoaded.add((note++"."++dyn).asFloat);
		});
		notNumbersLoaded=notNumbersLoaded.sort;

		// first determine the rate to get the right note
		while ({note<noteClosest},{
			note=note+12;
			rate=rate*0.5;
		});

		while ({note-noteClosest>11},{
			note=note-12;
			rate=rate*2;
		});
		rate=rate*Scale.chromatic.ratios[note-noteClosest];

		// determine the number of dynamics
		dyns=noteDynamics.at(noteClosest);
		if (dyns>1,{
			velIndices=Array.fill(dyns,{ arg i;
				i*128/(dyns-1)
			});
			velIndex=velIndices.indexOfGreaterThan(velocity)-1;
		});

		// determine the closest loaded note, in case both files are not available
		noteClosestLoaded=notNumbersLoaded[notNumbersLoaded.indexIn(note+((velIndex+1)/10))];
		if (noteClosestLoaded.notNil,{
			fileLoaded=noteNumbersLoadedDict[noteClosestLoaded];
			noteClosestLoaded=noteClosestLoaded.asInteger;
			while ({noteLoaded<noteClosestLoaded},{
				noteLoaded=noteLoaded+12;
				rateLoaded=rateLoaded*0.5;
			});
			while ({noteLoaded-noteClosestLoaded>11},{
				noteLoaded=noteLoaded-12;
				rateLoaded=rateLoaded*2;
			});
			rateLoaded=rateLoaded*Scale.chromatic.ratios[noteLoaded-noteClosestLoaded];
			[fileLoaded,rateLoaded].postln;
		});


		// determine file 1 and 2 interpolation
		file1=noteClosest.asInteger.asString++".";
		file2=noteClosest.asInteger.asString++".";
		if (dyns<2,{
			// simple playback using amp
			amp=velocity/127.0;
			file1=file1++"1.1.";
			file2=file2++"1.1.";
			// add round robin
			file1=file1++(noteRoundRobins.at(noteClosest.asString++".1").rand+1).asString++".0.wav";
			file2=file2++(noteRoundRobins.at(noteClosest.asString++".1").rand+1).asString++".0.wav";
		},{
			var rr1,rr2;
			amp=velocity/127.0/2+0.25;
			// gather the velocity indices that are available
			// TODO: make this specific to a single note?
			vels=[velIndices[velIndex],velIndices[velIndex+1]];
			buf1mix=(1-((velocity-vels[0])/(vels[1]-vels[0])));
			// add dynamic
			file1=file1++(velIndex+1).asInteger.asString++".";
			file2=file2++(velIndex+2).asInteger.asString++".";
			// add dynamic max
			file1=file1++dyns.asString++".";
			file2=file2++dyns.asString++".";
			// add round robin
			rr1=noteRoundRobins.at(noteClosest.asString++"."++(velIndex+1).asString);
			if (rr1.isNil,{
				rr1=1;
			});
			file1=file1++(rr1.rand+1).asString++".0.wav";
			rr2=noteRoundRobins.at(noteClosest.asString++"."++(velIndex+2).asString);
			if (rr2.isNil,{
				rr2=1;
			});
			file2=file2++(rr2.rand+1).asString++".0.wav";			
		});


		// check if buffer is loaded
		if (buf.at(file1).isNil,{
			if (buf.at(file2).isNil,{
				// no file1 and no file2
				if (fileLoaded.notNil,{
					"playing without 1+2".postln;
					this.doPlay(noteOriginal,amp,fileLoaded,fileLoaded,buf1mix,rateLoaded);
				});
				Buffer.read(server,PathName(folder+/+file2).fullPath,action:{ arg b1;
					b1.postln;
					buf.put(file2,b1);
					bufUsed.put(file2,SystemClock.seconds);
				});
			},{
				// only have buf2
				"playing without 1".postln;
				if (file2.notNil,{
					this.doPlay(noteOriginal,amp,file2,file2,buf1mix,rate);
				});
			});
			Buffer.read(server,PathName(folder+/+file1).fullPath,action:{ arg b1;
				b1.postln;
				buf.put(file1,b1);
				bufUsed.put(file1,SystemClock.seconds);
			});
		},{
			if (buf.at(file2).isNil,{
				// only have buf1
				"playing without 2".postln;
				this.doPlay(noteOriginal,amp,file1,file1,buf1mix,rate);
				Buffer.read(server,PathName(folder+/+file2).fullPath,action:{ arg b1;
					b1.postln;
					buf.put(file2,b1);
					bufUsed.put(file2,SystemClock.seconds);
				});
			},{
				// play original files!
				"playing without NONE!".postln;
				this.doPlay(noteOriginal,amp,file1,file2,buf1mix,rate);
			});
		});



	}

	sustain {
		arg on;
		pedalSustainOn=on;
		if (pedalSustainOn==false,{
			// release all sustained notes
			pedalSustainNotes.keysValuesDo({ arg note, val;
				if (voicesOn.at(note)==nil,{
					pedalSustainNotes.removeAt(note);
					this.noteOff(note);
				});
			});
		}, {
			// add currently down notes to the pedal
			voicesOn.keysValuesDo({ arg note, val;
				pedalSustainNotes.put(note,1);
			});
		});
	}


	sostenuto {
		arg on;
		pedalSostenutoOn=on;
		if (pedalSostenutoOn==false,{
			// release all sustained notes
			pedalSostenutoNotes.keysValuesDo({ arg note, val;
				if (voicesOn.at(note)==nil,{
					pedalSostenutoNotes.removeAt(note);
					this.noteOff(note);
				});
			});
		},{
			// add currently held notes
			voicesOn.keysValuesDo({ arg note, val;
				pedalSostenutoNotes.put(note,1);
			});
		});
	}

	noteOff {
		arg note;
		var keys;
		voicesOn.removeAt(note);
		if (pedalSustainOn==true,{
			pedalSustainNotes.put(note,1);
		},{
			if ((pedalSostenutoOn==true)&&(pedalSostenutoNotes.at(note)!=nil),{
				// do nothing, it is a sostenuto note
			},{
				// remove the sound
				if (syn.at(note).notNil,{
					keys=syn.at(note).keys.asArray;
					keys.do({ arg k,i;
						var v=syn.at(note).at(k);
						if (v.notNil,{
							if (v.isRunning,{
								if (v.isPlaying,{
									syn.at(note).removeAt(k);
									v.set(\gate,0);
								});
							});
						});
					});
				});
			});
		});

	}

	noteFade {
		arg note;
		var keys;
		if (syn.at(note).notNil,{
			keys=syn.at(note).keys.asArray;
			keys.do({ arg k,i;
				var v=syn.at(note).at(k);
				if (v.notNil,{
					if (v.isRunning,{
						if (v.isPlaying,{
							syn.at(note).removeAt(k);
							v.set(\gate,0,\release,params.at("fadetime"));
						});
					});
				});
			});
		});
	}


	doPlay {
		arg note,amp,file1,file2,buf1mix,rate;
		var notename=1000000.rand;
		var node;
		[notename,note,amp,file1,file2,buf1mix,rate].postln;
		// check if sound is loaded and unload it
		if (syn.at(note).isNil,{
			syn.put(note,Dictionary.new());
		});
		this.noteFade(note);
		bufUsed.put(file1,SystemClock.seconds);
		bufUsed.put(file2,SystemClock.seconds);
		node=Synth.head(server,"playx"++buf.at(file1).numChannels,[
			\out,busOutput,
			\amp,amp*params.at("amp"),
			\pan,params.at("pan"),
			\attack,params.at("attack"),
			\decay,params.at("decay"),
			\sustain,params.at("sustain"),
			\release,params.at("release"),
			\buf1,buf.at(file1),
			\buf2,buf.at(file2),
			\buf1mix,buf1mix,
			\rate,rate,
		]).onFree({
			syn.at(note).removeAt(notename);
		});
		syn.at(note).put(notename,node);
		voicesOn.put(note,1);
		NodeWatcher.register(node,true);
	}


	free {
		syn.keysValuesDo({arg note,v1;
			syn.at(note).keysValuesDo({ arg k,v;
				v.free;
			});
		});
		buf.keysValuesDo({ arg name,b;
			b.free;
		});
		synOutput.free;
		busOutput.free;
		bufUsed.free;
	}

}
