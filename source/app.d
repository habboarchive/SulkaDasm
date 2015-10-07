import std.stdio, std.getopt;
import colorize : fg, bg, mode, color, cwriteln, cwritefln;
import properties, engine;

void main(string[] args) {
	printLogo();

	string rsaN = Properties.defaultRsaN;
	string rsaE = Properties.defaultRsaE;
	bool disableRc4 = false;

	auto helpInformation = getopt(
		   args,
		   "rsaN|n", "Set custom RSA N Key.",  &rsaN,
		   "rsaE|e", "Set custom RSA E Key.",  &rsaE,
		   "disableRc4", "Disable RC4 Encryption.",  &disableRc4);

	if (args.length < 2) {
		writeln("Usage: SulkaDasm.exe file.swf");
		helpInformation.helpWanted = true;
	}

	if (helpInformation.helpWanted) {
		defaultGetoptPrinter("optionals options", helpInformation.options);
		return;
	}

	auto engine = new Engine(rsaN, rsaE, disableRc4);
	engine.executePatch(args[1]);
}

void printLogo() {
	cwriteln("############################".color(fg.red));
	cwritefln("SulkaDasm version %s".color(fg.red), Properties.appVersion);
	cwriteln("Written by Anthony93260".color(fg.red));
	cwriteln("anthony93260.github.io/SulkaDasm".color(fg.red));
	cwriteln("############################".color(fg.red));
}
