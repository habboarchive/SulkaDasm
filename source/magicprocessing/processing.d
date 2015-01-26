module magicprocessing.processing;

abstract class Processing {
	string asasmSpace = "     ";
	string asasmReturn = "\r\n";

	string asasmFilePath;
	patchStat stat;

	enum patchStat { finding, started, success }
	bool Patch();
}