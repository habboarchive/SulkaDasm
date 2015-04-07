module magicprocessing.processing;

import std.conv;
import std.file;
import std.regex;
import std.algorithm;

import model.methodmodel;

abstract class Processing {
	enum patchStat { finding, started, success }
	string asasmSpace = "     ";
	string asasmReturn = "\r\n";

	string rawContent;
	MethodModel[] methods;
	
	string asasmFilePath;
	patchStat stat;
	
	bool Patch();

	void processMethods() {
		rawContent = to!string(cast(char[])read(asasmFilePath));
		parseMethods();
	}

	void parseMethods() {		
		auto m = matchAll(this.rawContent, regex(r"trait method(.+?)end ; trait", "s"));

		while(!m.empty) {
			string rawMethodContent = m.front.hit;

			auto c = matchFirst(rawMethodContent, regex(`\("(?P<namespace>.+)"\),\s*"(?P<name>.+)"`));

			methods ~= new MethodModel(c["namespace"], c["name"], rawMethodContent);

			m.popFront();
		}
	}
}