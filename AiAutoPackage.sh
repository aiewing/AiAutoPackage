#!/bin/bash

# ⚠️⚠️使用方法：将脚本文件夹放置在桌面，参数配置好之后直接把脚本拖入终端 然后回车键即可执行
# ⚠️⚠️注意事项：由于此脚本不涉及证书及描述文件相关配置，所以需Xcode手动打包并导出成功后才能使用此脚本
############################ 参数配置 ###################################

# 如果ruby的版本不对，可以使用以下命令
#rvm use system
#rvm use 3.0.0 --default

# ⚠️打包环境，默认 Release 版，也可配置为 Debug
package_environment=Debug
# ⚠️打包导出类型(根据 plist 文件决定)，默认 AdHocExportOptions.plist
export_plist_name="DevelopmentExportOptions.plist"
# ⚠️更新日志
update_log=""
# ⚠️项目全路径(文件绝对路径，如"/Users/xxx/BaseProject/BaseProject.xcworkspace")
project_all_path="/Users/aiewing/Desktop/BFGit/xique-ios/TaTa.xcworkspace"

# ⚠️自动上传Fir  https://github.com/FIRHQ/fir-cli
# fir token
fir_api_Token="274d7e251ff4cbf99036fa82fe5034d9" # 不上传则不填
# fir 更新地址
fir_update_url="http://d.firim.pro/iOSliaoya"
# 钉钉机器人 webhook
dingtalk_access_token="https://oapi.dingtalk.com/robot/send?access_token=2d0fccdc920d9315bc2e81526cc173c4334faf72f7ca535f10976accc6552302"

# ⚠️自动上传蒲公英(uKey、_api_key)获取地址https://www.pgyer.com/doc/api#uploadApp 暂时还没试过
api_key="" # 不上传则不填
ukey=""  # 不上传则不填
pgy_installType=1   # 1、公开发布 2、密码安装
pgy_password=""     # 如果设置了密码安装则需要密码

## ⚠️自动上传苹果商店 - 苹果开发者账号 与 专用密码(需要提前设置 https://appleid.apple.com) 暂时还没试过
apple_id="" # 不上传则不填
apple_pwd="" # 不上传则不填
############################ 参数配置 ###################################

# 截取项目全称 （如：BaseProject.xcworkspace --> 项目名称、项目后缀）
project_full_name=${project_all_path##*/}
# 分割得 项目名称、项目后缀
pro_array=(${project_full_name//./ })
pro_name=${pro_array[0]}
pro_suffix=${pro_array[1]}
# 项目文件夹路径
project_all_path=${project_all_path%/*}

# 判断项目全称是否配置正确
if [ "${pro_suffix}" != "xcworkspace" ] && [ "${pro_suffix}" != "xcodeproj" ]; then
    echo "${CWARNING}⚠️项目名称配置错误，请正确配置project_full_name，如：BaseProject.xcworkspace 或 BaseProject.xcodeproj类型${CEND}"
    exit
fi

# 判断日志是否为空
if [ -z "$update_log" ]; then
    update_log="iOS ${package_environment} Development $(date "+%Y-%m-%d %H:%M:%S") 测试包"
fi

#while :; do
#  printf "
#选择你的打包版本类型：
#   ${CMSG}1${CEND}.Developers(开发版)
#   ${CMSG}2${CEND}.App Store(正式版)
#   ${CMSG}3${CEND}.AdHoc(测试版)
#   ${CMSG}4${CEND}.Enterprise(企业版)
#   ${CMSG}q${CEND}.退出打包脚本\n
#"
#  read -p "请输入打包类型: " number
#  if [[ ! ${number} =~ ^[1-4,q]$ ]]; then
#    echo "${CFAILURE}⚠️输入错误! 只允许输入 1 ~ 4 和 q${CEND}"
#  else
#    case "$number" in
#        1)
#          export_plist_name="DevelopmentExportOptions.plist"
#          break
#          ;;
#        2)
#          export_plist_name="AppStoreExportOptions.plist"
#          break
#          ;;
#        3)
#          export_plist_name="AdHocExportOptions.plist"
#          break
#          ;;
#        4)
#          export_plist_name="EnterpriseExportOptions.plist"
#          break
#          ;;
#        q)
#          exit
#          ;;
#    esac
#  fi
#done

# 根据需求判断上一步是否执行成功，传入执行结果：$? "执行步骤名"
judgementLastIsSuccsess() {
    if [ $1 -eq 0 ]; then
        echo -e "\n⭐️⭐️⭐️⭐️⭐️ $2 操作成功! ⭐️⭐️⭐️⭐️⭐️\n"
    else
        echo -e "\n😭😭😭😭😭 $2操作失败，终止脚本! 😭😭😭😭😭\n"
        exit
    fi
}

# 时间转换函数（秒转分钟）
timeTransformation() {
    if [ $1 -le 0 ]; then
        echo "============ ⚠️请检查项目是否能正常手动打包并导出ipa文件 ======="
        exit
    fi
    
    if [ $1 -gt 59 ]; then
        t_min=$[$1 / 60]
        t_second=$[$1 % 60]
        echo "============ 本次$2用时：${t_min}分${t_second}秒 ======="
    else
        echo "============ 本次$2用时：$1秒 ======="
    fi
}

# 打包开始时间（用于计算打包脚本执行时间）
begin_time=$(date +%s)
# 获取系统时间
date_string=`date +"%Y-%m-%d-%H-%M-%S"`

# 获取脚本当前所在目录(即上级目录绝对路径)
root_dir=$(cd "$(dirname "$0")"; pwd)
# IPA 文件导出时使用的 plist 文件路径
plist_path="${root_dir}/ExportOptions/${export_plist_name}"

# 切换到当前脚本的工作目录
cd ${root_dir}

# 所有打包文件导出时的临时存放目录（IPA、Achieve）
temp_path="${root_dir}/ExportIPAFile"
if [ ! -d ${temp_path} ]; then
   mkdir -p ${temp_path}
fi

# 切换到 temp_path 目录去创建存放 Archive 和 IPA 的文件夹
cd ${temp_path}
ipa_dir="${pro_name}-${date_string}(${package_environment})"
#ipa_dir="TaTa-2022-05-24-19-34-19(Debug)"
mkdir ${ipa_dir}

# 切换到项目根目录开始打包操作
cd "${project_all_path}"

echo "===== ${pro_name} 打包开始 ====="

# 如果没有使用cocoapods 反之if会处理
pro_clean=project
if [ ${pro_suffix} == "xcworkspace" ]; then
    pro_clean=workspace
fi

# 先组装 archive_path、ipa_path，用于导出 ipa 和 上传
archive_path="${temp_path}/${ipa_dir}/${pro_name}.xcarchive"
ipa_path="${temp_path}/${ipa_dir}/${pro_name}.ipa"

echo "===== ${pro_name} 开始Clean ====="

# Clean操作
xcodebuild clean -${pro_clean} ${project_full_name} -scheme ${pro_name} -configuration ${package_environment}
judgementLastIsSuccsess $? "Clean"

echo "===== ${pro_name} 开始Archive ====="

# Archive操作
xcodebuild archive -${pro_clean} ${project_full_name} -scheme ${pro_name} -configuration ${package_environment} -archivePath ${archive_path} -destination 'generic/platform=iOS'
judgementLastIsSuccsess $? "Archive"

echo "===== ${pro_name} 开始导出IPA文件 ====="

# 导出IPA文件操作
xcodebuild -exportArchive -archivePath ${archive_path} -exportOptionsPlist ${plist_path} -exportPath ${temp_path}/${ipa_dir}
judgementLastIsSuccsess $? "导出IPA文件"

# 删除 xcarchive 包
rm -r ${archive_path}

# 打包结束时间
end_time=$(date +%s)
# 计算打包时间(秒：s)
cost_time=$[${end_time} - ${begin_time}]
# 调用时间转换函数
timeTransformation ${cost_time} "打包"

echo "===== ${pro_name} 自动打包完成 ====="

# 打开 当前的 ipa 存放文件夹
open ${temp_path}/${ipa_dir}

########################## 上传Fir #################################
uploadFIR()
{
    echo "===== 正在上传 ${pro_name} 到 Fir ====="
    fir login -T ${fir_api_Token}       # fir.im token
    fir publish ${ipa_path} -c ${update_log} -Q -T ${fir_api_Token}
    judgementLastIsSuccsess $? "上传到Fir"
    
    # 钉钉机器人发消息的格式请参考钉钉官网开发文档
    if [ ! -z "$dingtalk_access_token" ]; then
    # 通知钉钉机器人
    echo "===== 通知钉钉机器人 ====="
    curl ${dingtalk_access_token} -H "Content-Type: application/json" -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"更新地址：${fir_update_url}，\n更新日志：${update_log}\"}}"
    fi
}

########################## 上传蒲公英 #################################
uploadPGY()
{
    # 判断配置是否为空，空则代表不上传
    if [ -z "${api_key}" ] || [ -z "${ukey}" ]; then
    echo "============ 请先配置蒲公英的 api_key & ukey ======="
    return
    fi
    # 上传开始时间
    upload_start_time=$(date +%s)
    # 开始上传
    echo "============ 正在上传 ${pro_name} 到 蒲公英 ======="
    curl -F "file=@${ipa_path}" -F "uKey=${ukey}" -F "_api_key=${api_key}" -F "installType=${pgy_installType}" -F "password=${pgy_password}" https://qiniu-storage.pgyer.com/apiv1/app/upload
    judgementLastIsSuccsess $? "上传蒲公英"
    echo "============ 上传结束 ======="
    # 上传结束时间
    upload_end_time=$(date +%s)
    # 计算上传时间(秒：s)
    upload_time=$[${upload_end_time} - ${upload_start_time}]
    # 调用时间转换函数
    timeTransformation ${upload_time} "上传蒲公英"
}

########################## 上传苹果商店 #################################
uploadAppStore()
{
    # 判断配置是否为空，空则代表不上传
    if [ -z "${apple_id}" ] || [ -z "${apple_pwd}" ]; then
    echo "============ 请先配置苹果商店的 apple_id & apple_pwd ======="
    return
    fi
    # 上传开始时间
    upload_start_time=$(date +%s)
    echo "============ AppStore 上传开始 ======="
    # 如果是命令安装的 Transporter，则路径为：/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/itms/bin/iTMSTransporter
    # 开始上传 - 这里用的是从 App Store 下载的 Transporter 上传工具【推荐】
    toolPath="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
    ${toolPath} -m upload -assetFile ${ipa_path} -u ${apple_id} -p ${apple_pwd} -v informational
    judgementLastIsSuccsess $? "上传App Store"
    echo "============ AppStore 上传结束 ======="
    # 上传结束时间
    upload_end_time=$(date +%s)
    # 计算上传时间(秒：s)
    upload_time=$[${upload_end_time} - ${upload_start_time}]
    # 调用时间转换函数
    timeTransformation ${upload_time} "上传App Store"
}

if [ "${export_plist_name}"x = "AppStoreExportOptions.plist"x ]; then
    # AppStore上传
    echo "===== AppStore上传 ====="
    uploadAppStore
elif [ ! -z "$fir_api_Token" ]; then
    # fir上传
    echo "===== fir上传 ====="
    uploadFIR
elif [ ! -z "$api_key" ]; then
    # 蒲公英上传
    echo "===== 蒲公英上传 ====="
    uploadPGY
else
    # 不需要上传
    echo "===== 不需要上传 ====="
fi


