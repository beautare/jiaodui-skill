@echo off
rem jiaodui.cmd — 校对助手 CLI（Windows cmd 包装入口）
rem 直接转发给 jiaodui.ps1，用法见 jiaodui.ps1 头部注释。
rem Key 读取顺序：-Key 参数 → %%JIAODUI_API_KEY%% 环境变量 → 脚本目录向上查找 .env。
rem 没有 Key 请先免费注册：https://jd.glowjames.top/register
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0jiaodui.ps1" %*
