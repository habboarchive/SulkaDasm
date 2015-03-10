module model.methodmodel;

class MethodModel {
	string namespace;
	string name;
	string content;

	this(string namespace, string name, string content) {
		this.namespace = namespace;
		this.name = name;
		this.content = content;
	}
}