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
import utils;

class Engine {
	string rsaN;
	string rsaE;
	bool disableRc4;
	
	string tempDirectory;
	string tempFilePath;
	string originalFilePath;	
	string fileName;
	string fileNameWihoutExtension;

	string asasmSpace = "     ";
	string asasmReturn = "\r\n";

	enum patchStat { finding, started, success }
	enum elementType { domainValidator, connectionHost, rsaKey }
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

		auto asasmFiles = dirEntries(tempDirectory, "*.asasm", SpanMode.depth);

		auto workers = new TaskPool();

		foreach(asasm; workers.parallel(asasmFiles)) {
			auto asasmContent = to!string(cast(char[])read(asasm));

			if(!canFind(elementList.keys, elementType.domainValidator)) {
				if(canFind(asasmContent, r"^([\\-a-z0-9.]+\\.)?varoke\\.net$")) {
					elementList[elementType.domainValidator] = asasm.name;
					cwritefln("Found domainValidator: %s".color(fg.cyan), baseName(asasm.name));
					continue;
				}
			}

			if(!canFind(elementList.keys, elementType.connectionHost)) {
				if(canFind(asasmContent, "Tried to connect to proxy but connection was null")) {
					elementList[elementType.connectionHost] = asasm.name;
					cwritefln("Found connectionHost: %s".color(fg.cyan), baseName(asasm.name));
					continue;
				}
			}

			if(!canFind(elementList.keys, elementType.rsaKey)) {
				if(canFind(asasmContent, "Invalid DH prime and generator")) {
					elementList[elementType.rsaKey] = asasm.name;
					cwritefln("Found rsaKey: %s".color(fg.cyan), baseName(asasm.name));
					continue;
				}
			}

			if(elementList.length == elementTypeCount) {
				workers.stop();
			}
		}

		if(elementList.length != elementTypeCount)
			throw new Exception("Could not found all required files, need to be updated??");
	}

	private void patchFiles() {
		writeln("Patching files...");

		foreach (element; parallel(elementList.keys.sort)) {
			auto newFileContent = appender!string();
			patchStat stat = patchStat.finding;

			switch(element) 
			{
				case elementType.domainValidator:
					bool firstPatchLocked = false;
					bool secondPatchLocked = true;

					auto asasmContent = to!string(cast(char[])read(elementList[element]));

					foreach(string line; utils.readLines(asasmContent)) {
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
					break;

				case elementType.connectionHost:
					bool firstPatchLocked = false;
					bool secondPatchLocked = true;

					auto asasmContent = to!string(cast(char[])read(elementList[element]));

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
					break;


				case elementType.rsaKey:
					bool canExecutePrePatch = false;

					auto asasmContent = to!string(cast(char[])read(elementList[element]));

					foreach(string line; utils.readLines(asasmContent)) {
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
					break;

				default:
					throw new Exception("Unknown element Type of " ~ to!string(element));
			}

			if(stat != patchStat.success)
				throw new Exception("Failed to patch " ~ to!string(element) ~ ", need to be updated??");

			std.file.write(elementList[element], newFileContent.data);
			cwritefln("%s sucessfully patched!".color(fg.cyan), to!string(element));
		}
	}

	private void replaceAsasm() {
		writeln("Replacing asasm resources...");

		foreach (abc; abcElementList) {
			string asasmPath = format("%s/%s.main.asasm", tempDirectory ~ abc, abc);
			writefln("Replacing %s", abc);
			rabcasm.execute(asasmPath);
		}
	}

	private void replaceAbc() {
		writeln("Replacing abc resources...");

		uint count;		
		foreach (abc; abcElementList) {
			string abcPath = format("%s/%s.main.abc", tempDirectory ~ abc, abc);
			writefln("Replacing %s", abc);
			abcreplace.execute([tempFilePath, to!string(count++), abcPath]);
		}
	}

	private void preCleanupAction() {
		writeln("Backup of the original file...");
		rename(originalFilePath, setExtension(originalFilePath, ".bak"));
		writeln("Copy the patched file...");
		copy(tempFilePath, originalFilePath);
	}
}