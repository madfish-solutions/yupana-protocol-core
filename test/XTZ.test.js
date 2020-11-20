const XTZ = artifacts.require("XTZ");

contract('XTZ', () => {

  console.log('test')

  let XTZ_Instancce;

  beforeEach(async () => {
    XTZ_Instancce = await XTZ.new();
  });



  it("deploy", async() => {
    console.log('done')
  });
});
