import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
class BrandHeader extends StatelessWidget {
 const BrandHeader({super.key});
 @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[ClipRRect(borderRadius:BorderRadius.circular(7),child:SizedBox(width:32,height:32,child:SvgPicture.asset('assets/icon/billit_logo.svg'))),const SizedBox(width:9),const Text('Billit Finance',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,letterSpacing:-.4))]);
}
