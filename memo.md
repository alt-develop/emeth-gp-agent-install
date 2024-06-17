1. gpu devicesをループ x
2. iommu_groupを特定 x
# for pci address
1. pci_address csvを取得
# for pci id
1. group配下のデバイス一覧を取得し、lspci結果をtmpfileへ出力
2. tmpfileからsedでpci id一覧を取得し、unique化
sed -n 's/.*\[\([0-9a-f]\{4\}:[0-9a-f]\{4\}\)\].*/\1/p'
1. CSV出力