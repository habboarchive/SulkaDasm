import std.stdio, std.getopt;
import engine, properties;

void main(string[] args)
{
    printLogo();

	if (args.length < 2) {
		throw new Exception("Usage: SulkaDasm.exe file.swf\nOptionnaly:--rsaN | --rsaE");
	}

	string rsaN = Properties.defaultRsaN;
	string rsaE = Properties.defaultRsaE;

	getopt(
		   args,
		   "rsaN",  &rsaN,
		   "rsaE",  &rsaE);

	auto engine = new Engine(rsaN, rsaE);
	engine.executePatch(args[1]);
}

void printLogo() {
	writeln("############################");
	writeln("SulkaDasm version " ~ Properties.appVersion);
	writeln("Written by Anthony93260");
	writeln("############################");
}
