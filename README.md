# Advertisment_Inteligens

こんにちは，シバタです．
プログラムをご覧いただきありがとうございます．
本プログラムは技育展2024に出展するプログラムです．
私が記述したのはAdvertisement_Inteligens/Advertisement_intligens/のコードです．
他の部分はshu223様のプログラムを引用させていただきました．
このようなアプリ開発は初めてで，本格的にプログラムを始めたのは9月の終わり頃です．この期間で挑戦したにしてはまあまあと言った所でしょうか．
ともあれ，参考にさせていただいたサイトやプログラムの作成者に感謝の意を表します．

このプログラムは，iOSデバイスのカメラで得られた動的な情報をGPT-4oでマルチモーダル処理をすることで，従来の方法と比べ，よりパーソナライズされた広告を選定します．さらに，その広告をAR空間の壁に表示させることで，よりインタラクティブな広告体験を提供します．

将来的にはVisionProなどの複合現実デバイスへの実装を目標にしています．
広告主と広告表示者（デバイス装着者），アプリケーション開発者にそれぞれインセンティブを支払うことによりアプリ開発の促進と，デバイスの装着意欲の促進を目的としています．

最終的には部屋の中に広告を表示するだけでなく，街中の広告も置き換えるようなものにすることです．
そのためには，コンテンツ制作者への利益還元と，デバイスの長時間の装着理由が必要と考えています．
あくまでも空間コンピューティングの体験を壊すことなく実装することを忘れてはいけません．

RealtimeARView
このプログラムではRealtimeARManatgerから得られた広告情報をAR空間の壁に表示します.

RealtimeARManager
このプログラムではARViewのカメラ映像からGPT-4oのマルチモーダルAIにAPIを用いて，擬似的な動画情報を送信し，優秀な広告コンサルタントであるGPT-4oが目の前の情報を元に有用な広告を提示します．今はテキストデータだけですが，より実用的な広告をつける予定です．


This program selects more personalized ads compared to conventional methods by multimodal processing of dynamic information obtained from the camera of iOS devices with GPT-4o. In addition, the advertisement is displayed on the wall of the AR space to provide a more interactive advertising experience.

Real time ARView
This program displays the advertising information obtained from RealtimeARManatger on the wall of the AR space.

Real-time AR Manager
In this program, APIs are used from ARView's camera footage to GPT-4o's multimodal AI to send pseudo-video information, and GPT-4o, an excellent advertising consultant, presents useful advertisements based on the information in front of you. I will. For now, it's only text data, but we plan to add more practical advertisements.

In the end, it is not only to display advertisements in the room, but also to replace advertisements in the city.

In order to do so, we believe that it is necessary to return profits to the content producer and the reason for wearing the device for a long time.

Don't forget to implement it without destroying the experience of spatial computing.

Real time ARView

This program displays the advertising information obtained from RealtimeARManatger on the wall of the AR space.




