module utils;

import std.algorithm;
import std.array;
import std.file;

public string[] readLines(string input)
{
    Appender!(string[]) result;
    foreach (line; input.splitter("\n"))
        result.put(line);
    return result.data;
}
