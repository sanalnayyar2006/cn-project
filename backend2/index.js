import express from "express"

const app = express()

app.get("/",(req,res)=>{
res.set("X-Backend","B");
res.set("Cache-Control","max-age=60")
 res.json({
	message : "Hii from server B"
})
})

app.get("/api/status",(req,res)=>{
  res.set("X-Backend","B");
  res.set("Cache-Control","no-store");
  res.json({ backend: "B", status: "ok", port: 5002, time: new Date().toISOString() })
})

app.listen(5002,()=>{
console.log("server B up and running http://localhost:5002")
})
