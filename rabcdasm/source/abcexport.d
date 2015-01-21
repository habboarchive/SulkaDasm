module abcexport;

import std.file;
import std.path;
import std.conv;
import std.stdio;
import swffile;

void execute(string filePath)
{
	try
	{
		scope swf = SWFFile.read(cast(ubyte[])read(filePath));
		uint count = 0;
		foreach (ref tag; swf.tags)
			if ((tag.type == TagType.DoABC || tag.type == TagType.DoABC2))
			{
				ubyte[] abc;
				if (tag.type == TagType.DoABC)
					abc = tag.data;
				else
				{
					auto p = tag.data.ptr+4; // skip flags
					while (*p++) {} // skip name
					abc = tag.data[p-tag.data.ptr..$];
				}
				std.file.write(stripExtension(filePath) ~ "-" ~ to!string(count++) ~ ".abc", abc);
			}
		if (count == 0)
			throw new Exception("No DoABC tags found");
	}
	catch (Exception e)
		writefln("Error while processing %s: %s", filePath, e);
}