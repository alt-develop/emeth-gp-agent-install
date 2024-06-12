iommu_groups=$(find /sys/kernel/iommu_groups/ -type l)

# IOMMUグループごとにデバイスを表示
for group in $(find /sys/kernel/iommu_groups/ -maxdepth 1 -mindepth 1 -type d); do
    group_no=$(basename "$group")
    echo "IOMMU Group $group_no:"
    for device in $(ls -1 "$group/devices"); do
        # PCIアドレスはcsvへ変換
        # PCI IDはtmpファイルへ一覧出力
        pci_address="$device"
        pci_id=$(lspci -nns "$pci_address" | awk '{print $3}')
        echo "  PCI Address: $pci_address, PCI ID: $pci_id"
    done
    echo ""
done

1. gpu devicesをループ x
2. iommu_groupを特定 x
# for pci address
3. pci_address csvを取得
# for pci id
4. group配下のデバイス一覧を取得し、lspci結果をtmpfileへ出力
5. tmpfileからsedでpci id一覧を取得し、unique化
sed -n 's/.*\[\([0-9a-f]\{4\}:[0-9a-f]\{4\}\)\].*/\1/p'
6. CSV出力