module magicprocessing.rsakeymodifier;

import std.array;
import std.string;
import std.conv;
import std.file;
import std.algorithm;
import magicprocessing.processing;
import util.string;

class RsaKeyModifier : Processing {

	string rsaN, rsaE;

	this(string asasmFilePath, string rsaN, string rsaE) {
		this.asasmFilePath = asasmFilePath;
		this.stat = patchStat.finding;

		this.rsaN = rsaN;
		this.rsaE = rsaE;
	}

	override bool Patch() {
		super.readContent();

		auto newFileContent = appender!string();

		bool canExecutePrePatch = false;

		foreach(ref line; util.string.readLines(this.rawContent)) {
			if(!stat != patchStat.success) {
				if(stat == patchStat.finding && canFind(line, "KeyObfuscator")) {								
					stat = patchStat.started;
					newFileContent.put(asasmSpace ~ format(" pushstring          \"%s\"", rsaN) ~ asasmReturn);
					continue;
				} else if(stat == patchStat.started && !canFind(line, "KeyObfuscator")) {
					continue;
				} else if(stat == patchStat.started && canFind(line, "KeyObfuscator")) {
					newFileContent.put(asasmSpace ~ format(" pushstring          \"%s\"", rsaE) ~ asasmReturn);
					canExecutePrePatch = true;
					stat = patchStat.success;
					continue;
				}
			}

			if(canExecutePrePatch) {
				canExecutePrePatch = false;							
				continue;
			}
			newFileContent.put(line ~ asasmReturn);
		}

		if(stat != patchStat.success) return false;

		write(this.asasmFilePath, newFileContent.data);

		return true;
	}
}