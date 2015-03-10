module magicprocessing.connectionhostmodifier;

import std.array;
import std.string;
import std.conv;
import std.file;
import std.algorithm;
import magicprocessing.processing;
import utils;

class ConnectionHostModifier : Processing {

	this(string asasmFilePath) {
		this.asasmFilePath = asasmFilePath;
		this.stat = patchStat.finding;
	}

	override bool Patch() {
		auto asasmContent = to!string(cast(char[])read(this.asasmFilePath));
		auto newFileContent = appender!string();

		bool firstPatchLocked = false;
		bool secondPatchLocked = true;

		foreach(string line; utils.readLines(asasmContent)) {
			if(!stat != patchStat.success) {
				if(!firstPatchLocked) {							
					if(stat == patchStat.finding && canFind(line, "parseInt")) {
						stat = patchStat.started;
					} else if(stat == patchStat.started && canFind(line, "getlocal            6")) {
						newFileContent.put(asasmSpace ~ " findpropstrict      QName(PackageNamespace(\"\"), \"getProperty\")" ~ asasmReturn);
						newFileContent.put(asasmSpace ~ " pushstring          \"connection.info.host\"" ~ asasmReturn);
						newFileContent.put(asasmSpace ~ " callproperty        QName(PackageNamespace(\"\"), \"getProperty\"), 1" ~ asasmReturn);
						firstPatchLocked = true;
						secondPatchLocked = false;
						continue;
					}
				} else if(!secondPatchLocked) {
					if(canFind(line, "65244") || canFind(line, "65185") || canFind(line, "65191") || canFind(line, "65189")
					   || canFind(line, "65188") || canFind(line, "65174") || canFind(line, "65238") || canFind(line, "65184")
					   || canFind(line, "65171") || canFind(line, "65172")) {
						   if(canFind(line, "65172")) {
							   secondPatchLocked = true;
							   stat = patchStat.success;
						   }
						   line = line.replace(line, asasmSpace ~ " pushint            65290" ~ asasmReturn);									   
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