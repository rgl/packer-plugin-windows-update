module github.com/rgl/packer-provisioner-windows-update

require (
	github.com/hashicorp/hcl/v2 v2.0.0
	github.com/hashicorp/packer v1.5.1
	github.com/shurcooL/httpfs v0.0.0-20190707220628-8d4bc4ba7749 // indirect
	github.com/shurcooL/vfsgen v0.0.0-20181202132449-6a9ea43bcacd // indirect
	github.com/zclconf/go-cty v1.1.2-0.20191126233707-f0f7fd24c4af
)

replace git.apache.org/thrift.git => github.com/apache/thrift v0.0.0-20180902110319-2566ecd5d999

go 1.13
