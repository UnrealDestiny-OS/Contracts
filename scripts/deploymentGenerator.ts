import FS from "fs";

export const GenerateDeployementFile = async (generation: { [key: string]: { address: string; abiPath: string } }) => {
  const deploymentData: any = {};
  const deploymentKeys = Object.keys(generation);

  for (let i = 0; i < deploymentKeys.length; i++) {
    await new Promise((res) => {
      FS.readFile("./artifacts/contracts/" + generation[deploymentKeys[i]].abiPath, (err, data) => {
        const parsedData = JSON.parse(data.toString());
        deploymentData[deploymentKeys[i]] = {
          address: generation[deploymentKeys[i]].address,
          abi: parsedData.abi,
        };
        res(true);
      });
    });
  }

  const parsedData = JSON.stringify(deploymentData);

  FS.writeFile("./deployment.json", parsedData, "utf-8", (error) => {
    if (error) console.log(error);
    else console.log("Deployment generation finished.");
  });

  FS.writeFile("C:\\Users\\sebas\\Documents\\Projects\\UnrealDestiny\\DAAP\\src\\core\\data\\deployment.json", parsedData, "utf-8", (error) => {
    if (error) console.log(error);
    else console.log("DAAP Deployment generation finished.");
  });

  FS.writeFile("C:\\Users\\sebas\\Documents\\Projects\\UnrealDestiny\\DataAPI\\src\\data\\deployment.json", parsedData, "utf-8", (error) => {
    if (error) console.log(error);
    else console.log("DAAP Deployment generation on the backend finished.");
  });
};
