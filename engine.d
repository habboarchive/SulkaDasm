module engine;

import std.stdio;
import std.string;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.regex;

import abcexport;
import rabcdasm;

class Engine {
	string rsaN;
	string rsaE;
	string tempDirectory;

	string originalFilePath;
	string tempFilePath;
	string fileName;
	string fileNameWihoutExtension;

	string release;
	string domainValidatorPath;

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

	private void cleanupTmpDirectory() {
		writeln("Deleting temporary directory..");
		foreach (string name; dirEntries(tempDirectory, SpanMode.depth)) {
			remove(name);
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
			/*writeln("Copying file to tmp directory");

			copy(filePath, tempDirectory ~ fileName);

			writeln("Exporting abc resources...");

			abcexport.execute(tempFilePath);

			writeln("Extracting abc resources...");

			auto abcFiles = dirEntries(tempDirectory,"*.abc", SpanMode.shallow);
			foreach(abc; abcFiles) {
				writeln("Extracting " ~ baseName(abc.name));
				rabcdasm.execute(abc.name);
			}*/

			writeln("Searching required asasm files...");

			auto asasmFiles = dirEntries(tempDirectory, "*.asasm", SpanMode.depth);
			foreach(asasm; asasmFiles) {
				auto asasmContent = to!string(cast(char[])read(asasm));
				if(release == null) {
					if(canFind(asasmContent, "RELEASE")) {
						/*auto m = matchFirst(asasmContent, regex("pushstring          \\\"([^>]*)\\\""));
						writeln("Found Release: " ~ m.hit);*/
						this.release = "...";
						continue;
					}
				}

				if(domainValidatorPath == null) {
					if(canFind(asasmContent, r"^([\\-a-z0-9.]+\\.)?varoke\\.net$")) {
						this.domainValidatorPath = asasm.name;
						writeln("Found domain validator: " ~ baseName(asasm.name));
						continue;
					}
				}
			}
		}
		catch(Exception e) {
			throw e;
		}
		finally {
			//cleanupTmpDirectory();
		}
	}
}
