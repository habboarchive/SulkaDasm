module magicprocessing.encoderdisabler;

import std.array;
import std.string;
import std.conv;
import std.file;
import std.algorithm;
import magicprocessing.processing;
import util.string;

class EncoderDisabler : Processing {

	this(string asasmFilePath) {
		this.asasmFilePath = asasmFilePath;
		this.stat = patchStat.finding;
	}

	override bool Patch() {
		super.readContent();

		auto newFileContent = appender!string();

		bool firstPatchLocked = false;
		bool secondPatchLocked = true;
		bool canExecutePostPatch = false;
		bool canExecutePrePatch = false;
		
		foreach(ref line; util.string.readLines(this.rawContent)) {
			if(stat != patchStat.success) {
				if(!firstPatchLocked) {
					if(stat == patchStat.finding && canFind(line, "/instance/send")) {
						stat = patchStat.started;
					} else if(stat == patchStat.started && canFind(line, "ByteArray") && !canExecutePostPatch && !canExecutePrePatch) {
						canExecutePostPatch = true;
					}

					if(canExecutePostPatch) {
						if(canFind(line, "pushnull")) {							
							canExecutePrePatch = true;
							canExecutePostPatch = false;							
						}						
					}

					if(canExecutePrePatch) {
						if(canFind(line, "ifne")) {
							line = line.replace("ifne", "ifeq");
							canExecutePrePatch = false;
							firstPatchLocked = true;
							secondPatchLocked = false;
							stat = patchStat.finding;
						}						
					}
				}

				if(!secondPatchLocked) {
					if(stat == patchStat.finding && canFind(line, "connected")) {
						stat = patchStat.started;						
					} else if(stat == patchStat.started && canFind(line, "getlocal0") && !canExecutePostPatch && !canExecutePrePatch) {
						canExecutePostPatch = true;						
						newFileContent.put(line ~ asasmReturn);
						continue;
					}

					if(canExecutePostPatch) {
						if(canFind(line, "getlocal0")) {
							canExecutePrePatch = true;
							canExecutePostPatch = false;
							continue;							
						}						
					}

					if(canExecutePrePatch) {
						if(canFind(line, "getproperty")) {
							continue;
						}

						if(canFind(line, "callproperty")) {
							canExecutePrePatch = false;
							secondPatchLocked = true;
							stat = patchStat.success;
							continue;
						}
					}
				}				
			}
			newFileContent.put(line ~ asasmReturn);
		}

		if(stat != patchStat.success) return false;

		write(this.asasmFilePath, newFileContent.data);

		return true;
	}
}