import 'dart:convert';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart';
import 'package:kamino/api/tmdb.dart';
import 'package:kamino/generated/i18n.dart';
import 'package:kamino/interface/search/genre_search.dart';
import 'package:kamino/main.dart';
import 'package:kamino/models/content.dart';
import 'package:kamino/ui/elements.dart';
import 'package:kamino/util/genre.dart';
import 'package:shimmer/shimmer.dart';

class BrowsePageState extends State<StatefulWidget> {

  Map<int, AsyncMemoizer> _genreMemoizers = new Map();

  final List genreList;
  final ContentType type;

  BrowsePageState({
    @required this.genreList,
    @required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: ListView(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints){
              double idealWidth = 200;
              double spacing = 10.0;

              return GridView.builder(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (constraints.maxWidth / idealWidth).round(),
                  childAspectRatio: 2,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: Genre.tv.length,
                itemBuilder: (BuildContext context, int index){
                  final int genreId = genreList[index]['id'];
                  final String genreAsset = Genre.getFontImagePath(
                      type,
                      genreId
                  );

                  if(_genreMemoizers[genreId] == null)
                    _genreMemoizers[genreId] = new AsyncMemoizer();
                  AsyncMemoizer memoizer = _genreMemoizers[genreId];

                  return Material(
                    type: MaterialType.card,
                    borderRadius: BorderRadius.circular(5),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder(
                        future: memoizer.runOnce(
                                () => fetchGenreData(genreId)
                        ),
                        builder: (BuildContext context, AsyncSnapshot snapshot){
                          if(snapshot.hasError){
                            print("Error loading genre: #$genreId");
                            return Container();
                          }

                          switch(snapshot.connectionState){
                            case ConnectionState.none:
                            case ConnectionState.waiting:
                            case ConnectionState.active:
                              return Shimmer.fromColors(
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Container(
                                        color: const Color(0x8F000000),
                                      ),
                                    )
                                  ],
                                ),
                                baseColor: const Color(0x1F000000),
                                highlightColor: const Color(0x3FFFFFFF)
                              );

                            case ConnectionState.done:
                              return Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.center,
                                children: <Widget>[
                                  CachedNetworkImage(
                                    imageUrl: TMDB.IMAGE_CDN_LOWRES + snapshot.data[0]['backdrop_path'],
                                    fit: BoxFit.cover,
                                  ),

                                  Container(
                                    color: const Color(0x8F000000),
                                    child: Center(child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 30
                                        ),
                                        height: 30,
                                        child: SvgPicture.asset(genreAsset)
                                    )),
                                  ),

                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (BuildContext context) => GenreSearch(
                                                genreID: genreId,
                                                genreName: Genre.resolveGenreName(
                                                    getRawContentType(type),
                                                    genreId
                                                ),
                                                contentType: getRawContentType(type),
                                              )
                                          )
                                      ),
                                    ),
                                  )
                                ],
                              );
                          }
                        }
                    )
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  Future<List> fetchGenreData(int genreId) async {
    String url = "${TMDB.ROOT_URL}/discover/${getRawContentType(type)}"
        "${TMDB.getDefaultArguments(context)}&"
        "sort_by=popularity.desc&include_adult=false"
        "&include_video=false&"
        "page=1&with_genres=$genreId";

    var response = jsonDecode((await get(url)).body);
    // Status code 25 -> rate limit
    if(response['status_code'] != null && response['status_code'] == 25){
      await Future.delayed(Duration(seconds: 4));
      return await fetchGenreData(genreId);
    }

    return response['results'];
  }

}

class BrowseTVShowsPage extends KaminoAppPage {

  static const List genreList = Genre.tv;
  static const ContentType type = ContentType.TV_SHOW;

  @override
  State<StatefulWidget> createState() => BrowsePageState(
    genreList: genreList,
    type: type
  );

  @override
  Widget buildHeader(BuildContext context){
    return TitleText(S.of(context).tv_shows, fontSize: 26);
  }

}

class BrowseMoviesPage extends KaminoAppPage {

  static const List genreList = Genre.movie;
  static const ContentType type = ContentType.MOVIE;

  @override
  State<StatefulWidget> createState() => BrowsePageState(
      genreList: genreList,
      type: type
  );

  @override
  Widget buildHeader(BuildContext context){
    return TitleText(S.of(context).movies, fontSize: 26);
  }

}