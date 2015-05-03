module magicprocessing.domainvalidatordisabler;

import std.array;
import std.string;
import std.conv;
import std.file;
import std.algorithm;
import magicprocessing.processing;
import util.string;

import colorize : fg, bg, mode, color, cwriteln, cwritefln;

class DomainValidatorDisabler : Processing {

	this(string asasmFilePath) {
		this.asasmFilePath = asasmFilePath;
		this.stat = patchStat.finding;
	}

	override bool Patch() {
		super.readContent();

		auto newFileContent = appender!string();

		bool firstPatchLocked = false;
		bool secondPatchLocked = true;

		foreach(ref line; util.string.readLines(this.rawContent)) {
			if(stat != patchStat.success) {
				if(!firstPatchLocked) {
					if(stat == patchStat.finding && canFind(line, "getlocal0")) {
						stat = patchStat.started;
						continue;
					} else if(stat == patchStat.started) {
						if(canFind(line, "returnvoid")) {
							firstPatchLocked = true;
							secondPatchLocked = false;
							stat = patchStat.finding;
						}
						continue;
					}
				}

				if(!secondPatchLocked) {
					if(stat == patchStat.finding && canFind(line, r"^([\\-a-z0-9.]+\\.)?habbo\\.com\\.(br|es|tr)$")) {
						stat = patchStat.started;
					} else if(stat == patchStat.started && canFind(line, "returnvalue")) {
						newFileContent.put(asasmSpace ~ "pushtrue" ~ asasmReturn);
						stat = patchStat.success;
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