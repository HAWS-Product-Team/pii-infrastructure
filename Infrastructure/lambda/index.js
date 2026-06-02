exports.handler = async (event) => {
  console.log("Incoming event:", JSON.stringify(event));

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "PII API working"
    })
  };
};