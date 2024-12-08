#!/bin/bash

# AWS bölgelerini belirtin
REGIONS=("us-east-1" "us-east-2" "ap-northeast-1" "eu-central-1" "eu-west-1" "eu-north-1" "us-west-2" "us-west-1" "eu-west-2" "eu-west-3")  # Kendi bölgelerinizi buraya ekleyin

# GitHub URL
GITHUB_REPO="https://github.com/korkmazbsk/monsta.git"

# Çıktı logları
SUCCESS_LOG="success_regions.log"
FAILED_LOG="failed_regions.log"

# Log dosyalarını temizle
> $SUCCESS_LOG
> $FAILED_LOG

# AWS CLI ile bölge bazlı işlemler
for REGION in "${REGIONS[@]}"; do
    echo "Processing region: $REGION"

    # Sunucuları listele
    INSTANCE_IDS=$(aws ec2 describe-instances --region "$REGION"         --query "Reservations[*].Instances[*].InstanceId"         --output text)

    if [ -z "$INSTANCE_IDS" ]; then
        echo "No instances found in $REGION"
        echo "$REGION" >> $FAILED_LOG
        continue
    fi

    # Her bir sunucuya bağlan ve işlemleri gerçekleştir
    for INSTANCE_ID in $INSTANCE_IDS; do
        echo "Connecting to instance: $INSTANCE_ID in region $REGION"

        # Sunucu erişim bilgilerini al
        PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION"             --instance-ids "$INSTANCE_ID"             --query "Reservations[0].Instances[0].PublicIpAddress"             --output text)

        if [ -z "$PUBLIC_IP" ]; then
            echo "No public IP for instance $INSTANCE_ID in $REGION"
            echo "$REGION" >> $FAILED_LOG
            continue
        fi

        # Root kullanıcısı olarak bağlantı ve işlemler
        ssh -o StrictHostKeyChecking=no root@$PUBLIC_IP <<EOF
        echo "Connected to $INSTANCE_ID in $REGION"

        # GitHub reposunu klonla
        git clone $GITHUB_REPO /root

        # Klasöre gir ve izinleri ayarla
        cd /root/monsta
        chmod 777 tnn-miner-cpu

        # Script'i çalıştır
        bash tintin.sh
        echo "Monsta setup completed on $INSTANCE_ID in $REGION"
EOF

        if [ $? -eq 0 ]; then
            echo "$REGION" >> $SUCCESS_LOG
        else
            echo "$REGION" >> $FAILED_LOG
        fi
    done
done

# Özet sonuçları göster
echo "Deployment summary:"
echo "Success regions:"
cat $SUCCESS_LOG
echo "Failed regions:"
cat $FAILED_LOG
