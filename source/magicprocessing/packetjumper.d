module magicprocessing.packetjumper;

import std.array;
import std.string;
import std.conv;
import std.file;
import std.algorithm;
import magicprocessing.processing;
import util.string;
import model.methodmodel;

class PacketJumper : Processing {

	this(string asasmFilePath) {
		this.asasmFilePath = asasmFilePath;
		this.stat = patchStat.finding;
	}

	override bool Patch() {
		super.readContent();
		super.parseMethods();
		
		auto sendHelloMethod = findSendHelloMethod();
		auto helloMethod = findHelloMethod();

		if(helloMethod is null && sendHelloMethod is null) return false;

		auto newMethodContent = appender!string();

		ulong local2Count = count(sendHelloMethod.content, "getlocal2"), local2Found = 0;

		foreach(ref line; util.string.readLines(sendHelloMethod.content)) {
			if(stat != patchStat.success) {
				if(stat == patchStat.finding && canFind(line, "getlocal2")) {
					local2Found++;

					if(local2Found == local2Count) {
						stat = patchStat.started;
						continue;
					}
				} else if(stat == patchStat.started) {
					if(canFind(line, "findpropstrict")) {
						continue;
					} else if(canFind(line, "constructprop")) {
						continue;
					} else if(canFind(line, "callpropvoid")) {
						newMethodContent.put(asasmSpace ~ " getlocal0" ~ asasmReturn);
						newMethodContent.put(asasmSpace ~ " getlocal2" ~ asasmReturn);
						newMethodContent.put(asasmSpace ~ format(" callpropvoid        QName(PrivateNamespace(\"%s\"), \"%s\"), 1", helloMethod.namespace, helloMethod.name) ~ asasmReturn);
						stat = patchStat.success;
						continue;
					}
				}
			}
			newMethodContent.put(line ~ asasmReturn);
		}

		if(stat != patchStat.success) return false;

		string newContent = this.rawContent.replace(sendHelloMethod.content, newMethodContent.data);

		write(this.asasmFilePath, newContent);

		return true;
	}

	MethodModel findSendHelloMethod() {
		foreach(ref method; this.methods) {
			if(canFind(method.content, "flash.events") && canFind(method.content, "optional Null()") && canFind(method.content, "connection")) {
				return method;
			}
		}
		return null;
	}

	MethodModel findHelloMethod() {
		foreach(ref method; this.methods) {
			if(canFind(method.content, "machineid") && canFind(method.content, "send")) {
				return method;
			}
		}
		return null;
	}
}