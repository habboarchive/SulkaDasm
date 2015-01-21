import std.stdio, std.getopt;
import colorize : fg, bg, mode, color, cwriteln, cwritefln;
import properties, engine;

void main(string[] args) {
	printLogo();

	if (args.length < 2)
		throw new Exception("Usage: SulkaDasm.exe file.swf\n\nOptionnaly:\n--rsaN - Set RSA N Key\n--rsaE - Set RSA E Key\n--disableRc4 - Disable RC4 Encryption");

	string rsaN = Properties.defaultRsaN;
	string rsaE = Properties.defaultRsaE;
	bool disableRc4 = false;

	getopt(
		   args,
		   "rsaN",  &rsaN,
		   "rsaE",  &rsaE,
		   "disableRc4",  &disableRc4);

	auto engine = new Engine(rsaN, rsaE, disableRc4);
	engine.executePatch(args[1]);
}

void printLogo() {
	cwriteln("############################".color(fg.red));
	cwritefln("SulkaDasm version %s".color(fg.red), Properties.appVersion);
	cwriteln("Written by Anthony93260".color(fg.red));
	cwriteln("############################".color(fg.red));
}
