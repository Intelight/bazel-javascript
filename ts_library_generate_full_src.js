const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const buildfileDir = path.dirname(process.argv[2]);
const destinationDir = process.argv[3];
fs.mkdirSync(destinationDir);
fs.mkdirSync(path.join(destinationDir, "node_modules"));
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify({}, null, 2),
  "utf8"
);
fs.writeFileSync(
  path.join(destinationDir, "tsconfig.json"),
  JSON.stringify(
    {
      target: "esnext",
      module: "esnext",
      strict: true
    },
    null,
    2
  ),
  "utf8"
);

const pathToPackagedPath = {};

for (let i = 4; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.indexOf(":") !== -1) {
    const [
      targetPackage,
      targetName,
      joinedSrcs,
      compiledDir,
      fullSrcDir
    ] = arg.split(":");
    const srcs = joinedSrcs.split("|");
    const rootModuleName =
      "__" + targetPackage.replace(/\//g, "__") + "__" + targetName;
    for (const src of srcs) {
      pathToPackagedPath[
        path.join(path.dirname(src), path.parse(src).name)
      ] = path.join(
        rootModuleName,
        path.relative(targetPackage, path.dirname(src)),
        path.parse(src).name
      );
    }
    // Copy target dependencies.
    fs.copySync(
      path.join(fullSrcDir, "node_modules"),
      path.join(destinationDir, "node_modules"),
      {
        dereference: true
      }
    );
    // Copy target itself.
    fs.copySync(
      compiledDir,
      path.join(destinationDir, "node_modules", rootModuleName),
      {
        dereference: true
      }
    );
  } else {
    const sourceFilePath = arg;
    if (!fs.existsSync(sourceFilePath)) {
      throw new Error(`Missing file: ${sourceFilePath}.`);
    }
    // TODO: Create directories recursively as required.
    const destinationFilePath = path.join(
      destinationDir,
      path.relative(buildfileDir, sourceFilePath)
    );
    const sourceText = fs.readFileSync(sourceFilePath, "utf8");
    const sourceFile = ts.createSourceFile(
      path.basename(sourceFilePath),
      sourceText,
      ts.ScriptTarget.Latest,
      true
    );
    for (const statement of sourceFile.statements) {
      // TODO: Also handle require statements.
      if (statement.kind === ts.SyntaxKind.ImportDeclaration) {
        const importFrom = statement.moduleSpecifier.text;
        let replaceWith;
        for (const potentialImportPath of Object.keys(pathToPackagedPath)) {
          if (path.join(buildfileDir, importFrom) === potentialImportPath) {
            replaceWith = pathToPackagedPath[potentialImportPath];
          }
        }
        if (!replaceWith) {
          // It could well be a perfectly correct reference to an external module
          // or another file in the same target.
          // This will fail at compilation time if there is no match.
          continue;
        }
        statement.moduleSpecifier = ts.createLiteral(replaceWith);
      }
    }
    const updatedFile = ts.createPrinter().printFile(sourceFile);
    fs.writeFileSync(destinationFilePath, updatedFile, "utf8");
  }
}
