'''
Author: 
Date: 2025-01-13 10:47:22
LastEditors: 
LastEditTime: 2025-01-13 10:47:29
Description: file content
'''
from PIL import Image

def resize_image(input_path, output_path, size):
    """将图像调整为指定尺寸"""
    with Image.open(input_path) as img:
        img_resized = img.resize((size, size), Image.ANTIALIAS)
        img_resized.save(output_path)
        print(f"保存缩小后的图像: {output_path}")

def create_black_or_white_version(input_path, output_path, color):
    """
    创建黑白版本图像，将非透明部分变为指定颜色（黑或白）。
    :param input_path: 输入图像路径
    :param output_path: 输出图像路径
    :param color: 'black' 或 'white'
    """
    with Image.open(input_path) as img:
        # 确保图像是 RGBA 模式
        img = img.convert("RGBA")
        datas = img.getdata()

        new_data = []
        for item in datas:
            # item 是一个 (R, G, B, A) 元组
            if item[3] > 0:  # 如果像素不透明
                if color == 'black':
                    new_data.append((0, 0, 0, item[3]))  # 黑色，保留原来的透明度
                elif color == 'white':
                    new_data.append((255, 255, 255, item[3]))  # 白色，保留原来的透明度
            else:
                new_data.append(item)  # 保留透明像素

        img.putdata(new_data)
        img.save(output_path)
        print(f"保存{color}版本图像: {output_path}")

def main():
    input_file = "logo-1024.png"
    output_sizes = [512, 256, 128, 32]
    
    # 生成不同尺寸的图像
    for size in output_sizes:
        output_file = f"logo-{size}.png"
        resize_image(input_file, output_file, size)
    
    # 创建黑白版本的 logo-32.png
    create_black_or_white_version("logo-32.png", "logo-32-black.png", "black")
    create_black_or_white_version("logo-32.png", "logo-32-white.png", "white")

if __name__ == "__main__":
    main()
