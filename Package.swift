import PackageDescription

let package = Package(
   name: "Theater",
   dependencies: [
    .Package(url: "http://github.com/Huawei-PTLab/SWORDS.git", versions: Version(0,1,2)..<Version(1,0,0)),
   ],
   exclude: ["Docs", "theaterlogo.jpeg"]
)

