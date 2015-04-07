module engine;

import std.stdio;
import std.string;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.container;
import std.array;
import std.parallelism;

import colorize : fg, color, cwriteln, cwritefln;
import abcexport, abcreplace, rabcdasm, rabcasm;

import util.string;
import magicprocessing.rsakeymodifier;
import magicprocessing.connectionhostmodifier;
import magicprocessing.domainvalidatordisabler;
import magicprocessing.encoderdisabler;
import magicprocessing.packetjumper;

class Engine {
	string rsaN;
	string rsaE;
	bool disableRc4;
	
	string tempDirectory;
	string tempFilePath;
	string originalFilePath;	
	string fileName;
	string fileNameWihoutExtension;	
	
	enum elementType { domainValidator, connectionHost, rsaKey, encoder }
	string[elementType] elementList;
	string[] abcElementList;

	this(string rsaN, string rsaE, bool disableRc4) {
		this.rsaN = rsaN;
		this.rsaE = rsaE;
		this.disableRc4 = disableRc4;
	}

	void executePatch(string filePath) {
		if(!exists(filePath)) 
			throw new Exception("Specified file not found");

		createTempDirectory();

		this.originalFilePath = filePath;		
		this.fileName = baseName(filePath);
		this.fileNameWihoutExtension = baseName(stripExtension(filePath));
		this.tempFilePath = tempDirectory ~ fileName;

		if(this.disableRc4) {
			cwriteln("Rc4 will be disabled!".color(fg.yellow));
		}

		try
		{			
			prepareFile();
			exportAbc();
			extractAbc();
			findRequiredFiles();
			patchFiles();
			replaceAsasm();
			replaceAbc();
			preCleanupAction();

			cwritefln("%s was sucessfully patched!".color(fg.green), fileName);
		}
		catch(Exception e) {
			throw e;
		}
		finally {
			cleanupTempDirectory();
		}
	}

	private void createTempDirectory() {
		this.tempDirectory = getcwd() ~ "/.tmp/";

		if(exists(this.tempDirectory)) {
			cleanupTempDirectory();
		}

		mkdir(this.tempDirectory);

		version(Windows) {
			setAttributes(tempDirectory, 0x2); // Hide
		}
	}

	private void cleanupTempDirectory() {
		writeln("Deleting temporary directory..");
		rmdirRecurse(tempDirectory);
	}

	private void prepareFile() {
		writeln("Copying file to tmp directory");
		copy(originalFilePath, tempDirectory ~ fileName);
	}

	private void exportAbc() {
		writeln("Exporting abc resources...");
		abcexport.execute(tempFilePath);
	}

	private void extractAbc() {
		writeln("Extracting abc resources...");

		auto abcFiles = dirEntries(tempDirectory,"*.abc", SpanMode.shallow);
		foreach(abc; parallel(abcFiles)) {
			writefln("Extracting %s", baseName(abc.name));
			abcElementList ~= baseName(stripExtension(abc.name));
			rabcdasm.execute(abc.name);
		}
	}

	private void findRequiredFiles() {
		writeln("Searching required asasm files...");

		auto elementTypeCount = [ __traits(allMembers, elementType) ].length;
		elementTypeCount -= !this.disableRc4 ? 1 : 0;

		auto asasmFiles = dirEntries(tempDirectory, "*.asasm", SpanMode.depth);

		auto workers = new TaskPool();

		foreach(asasm; workers.parallel(asasmFiles)) {
			auto asasmContent = to!string(cast(char[])read(asasm));

			if(!canFind(elementList.keys, elementType.domainValidator)) {
				if(canFind(asasmContent, r"^([\\-a-z0-9.]+\\.)?varoke\\.net$")) {
					elementList[elementType.domainValidator] = asasm.name;
					cwritefln("Found domainValidator: %s".color(fg.cyan), baseName(stripExtension(asasm.name)));
					continue;
				}
			}

			if(!canFind(elementList.keys, elementType.connectionHost)) {
				if(canFind(asasmContent, "Tried to connect to proxy but connection was null")) {
					elementList[elementType.connectionHost] = asasm.name;
					cwritefln("Found connectionHost: %s".color(fg.cyan), baseName(stripExtension(asasm.name)));
					continue;
				}
			}

			if(!canFind(elementList.keys, elementType.rsaKey)) {
				if(canFind(asasmContent, "Invalid DH prime and generator")) {
					elementList[elementType.rsaKey] = asasm.name;
					cwritefln("Found rsaKey: %s".color(fg.cyan), baseName(stripExtension(asasm.name)));
					continue;
				}
			}

			if(this.disableRc4 && !canFind(elementList.keys, elementType.encoder)) {
				if(canFind(asasmContent, "connected") && canFind(asasmContent, "writeBytes")) {
					elementList[elementType.encoder] = asasm.name;
					cwritefln("Found encoder: %s".color(fg.cyan), baseName(stripExtension(asasm.name)));
					continue;
				}
			}			

			if(elementList.length >= elementTypeCount) {
				workers.stop();
			}
		}

		if(elementList.length != elementTypeCount)
			throw new Exception("Could not find all required files, damn!");
	}

	private void patchFiles() {
		writeln("Patching files...");

		foreach (ref element; sort(elementList.keys)) {
			bool isPatchSuccess = false;
			string asasmPath = elementList[element];

			switch(element) 
			{
				case elementType.domainValidator:
					auto domainValidatorDisabler = new DomainValidatorDisabler(asasmPath);
					isPatchSuccess = domainValidatorDisabler.Patch();
					break;

				case elementType.connectionHost:
					auto connectionHostModifier = new ConnectionHostModifier(asasmPath);
					isPatchSuccess = connectionHostModifier.Patch();
					break;

				case elementType.rsaKey:
					if(!this.disableRc4) {
						auto rsaKeyModifier = new RsaKeyModifier(asasmPath, rsaN, rsaE);
						isPatchSuccess = rsaKeyModifier.Patch();
					} else {
						auto packetJumper = new PacketJumper(asasmPath);
						isPatchSuccess = packetJumper.Patch();
					}
					break;

				case elementType.encoder:
					auto encoderDisabler = new EncoderDisabler(asasmPath);
					isPatchSuccess = encoderDisabler.Patch();
					break;

				default:
					throw new Exception("Unknown element Type of " ~ to!string(element));
			}

			if(!isPatchSuccess)
				throw new Exception("Failed to patch " ~ to!string(element) ~ ", damn!");

			cwritefln("%s successfully patched!".color(fg.cyan), to!string(element));
		}
	}

	private void replaceAsasm() {
		writeln("Replacing asasm resources...");

		foreach (ref abc; abcElementList) {
			string asasmPath = format("%s/%s.main.asasm", tempDirectory ~ abc, abc);
			writefln("Replacing %s", abc);
			rabcasm.execute(asasmPath);
		}
	}

	private void replaceAbc() {
		writeln("Replacing abc resources...");

		uint count = 0;		
		foreach (ref abc; abcElementList) {
			string abcPath = format("%s/%s.main.abc", tempDirectory ~ abc, abc);
			writefln("Replacing %s", abc);
			auto index = to!string(count++);
			abcreplace.execute([tempFilePath, index, abcPath]);
		}
	}

	private void preCleanupAction() {
		writeln("Backup of the original file...");
		rename(originalFilePath, setExtension(originalFilePath, ".bak"));
		writeln("Copy the patched file...");
		copy(tempFilePath, originalFilePath);
	}
}