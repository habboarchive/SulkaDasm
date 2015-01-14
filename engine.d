module engine;

import std.stdio;
import std.string;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.container;
import std.array;

import abcexport;
import abcreplace;
import rabcdasm;
import rabcasm;
import utils;

class Engine {
	string rsaN;
	string rsaE;
	string tempDirectory;

	string originalFilePath;
	string tempFilePath;
	string fileName;
	string fileNameWihoutExtension;

	string[] abcElementList;

	enum elementType { domainValidator, rsaKey }
	string[elementType] elementList;

	enum patchStat { finding, started, success }

	this(string rsaN, string rsaE) {
		this.rsaN = rsaN;
		this.rsaE = rsaE;

		createAndSetTempDirectory();
	}

	private void createAndSetTempDirectory() {
		this.tempDirectory = getcwd() ~ "\\tmp\\";
		if(!exists(this.tempDirectory)) {
			mkdir(this.tempDirectory);
		}
	}

	void executeCrack(string filePath) {
		if(!exists(filePath)) 
			throw new Exception("Specified file not found");

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

			writeln(fileName ~ " was sucessfully patched!");
		}
		catch(Exception e) {
			throw e;
		}
		finally {
			//cleanupTmpDirectory();
		}
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
		foreach(abc; abcFiles) {
			writeln("Extracting " ~ baseName(abc.name));
			abcElementList ~= baseName(stripExtension(abc.name));
			rabcdasm.execute(abc.name);
		}
	}

	private void findRequiredFiles() {
		writeln("Searching required asasm files...");

		auto asasmFiles = dirEntries(tempDirectory, "*.asasm", SpanMode.depth);
		foreach(asasm; asasmFiles) {
			auto asasmContent = to!string(cast(char[])read(asasm));

			if(!canFind(elementList.keys, elementType.domainValidator)) {
				if(canFind(asasmContent, r"^([\\-a-z0-9.]+\\.)?varoke\\.net$")) {
					elementList[elementType.domainValidator] = asasm.name;
					writeln("Found domain validator: " ~ baseName(asasm.name));
					continue;
				}
			}
		}

		if(elementList.length != 1) {
			throw new Exception("Could not found all required files");
		}
	}

	private void patchFiles() {
		writeln("Patching files...");

		foreach (element; elementList.keys.sort)
		{
			auto newFileContent = appender!string();
			patchStat stat = patchStat.finding;

			switch(element) 
			{
				case elementType.domainValidator:
					foreach(string line; utils.readLines(cast(string)(read(elementList[element])))) {
						if(stat != patchStat.success) {
							if(stat == patchStat.finding && canFind(line, r"^([\\-a-z0-9.]+\\.)?habbo\\.com\\.(br|es|tr)$")) {
								stat = patchStat.started;
							} else if(stat == patchStat.started && canFind(line, "returnvalue")) {
								line = line.replace("returnvalue", "pushtrue");
								stat = patchStat.success;
							}
						}
						newFileContent.put(line ~ "\r\n");
					}
					break;

				default:
					throw new Exception("Unknown element Type of " ~ to!string(element));
			}

			if(stat != patchStat.success) {
				throw new Exception("Failed to patch " ~ to!string(element));
			}

			std.file.write(elementList[element], newFileContent.data);
			writeln(to!string(element) ~ " sucessfully patched!");
		}
	}

	private void replaceAsasm() {
		writeln("Replacing asasm resources...");

		foreach (abc; abcElementList) {
			string asasmPath = format("%s\\%s.main.asasm", tempDirectory ~ abc, abc);
			writeln("Replacing " ~ abc);
			rabcasm.execute(asasmPath);
		}
	}

	private void replaceAbc() {
		writeln("Replacing abc resources...");

		uint count;
		foreach (abc; abcElementList) {
			string abcPath = format("%s\\%s.main.abc", tempDirectory ~ abc, abc);
			writeln("Replacing " ~ abc);
			abcreplace.execute([tempFilePath, to!string(count++), abcPath]);
		}
	}

	private void preCleanupAction() {
		writeln("Backup of the original file...");
		rename(originalFilePath, originalFilePath ~ ".bak");
		writeln("Copy the patched file...");
		copy(tempFilePath, originalFilePath);
	}

	private void cleanupTmpDirectory() {
		writeln("Deleting temporary directory..");
		foreach (string name; dirEntries(tempDirectory, SpanMode.depth)) {
			remove(name);
		}
	}
}
