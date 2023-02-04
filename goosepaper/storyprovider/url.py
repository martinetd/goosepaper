import sys
import datetime
import requests
import re
from typing import List
from readability import Document

from .storyprovider import StoryProvider
from ..story import Story


class URLFeedStoryProvider(StoryProvider):
    def __init__(
        self,
        url: str,
        limit: int = 5,
    ) -> None:
        self.limit = limit
        self.url = url

    def get_stories(self, limit: int = 5, **kwargs) -> List[Story]:
        req = requests.get(self.url)
        stories = []
        if not req.ok:
            print(f"{self.url}: failed to get", file=sys.stderr)
            exit(1)

        doc = Document(req.content)
        title = doc.title().strip()

        story = Story(
            title,
            body_html=doc.summary(),
            byline=self.url,
            date=datetime.datetime.now(),
        )
        # print to stdout for filename
        alnum = re.compile('[\W_]+')
        print(alnum.sub('_', title)[0:200])

        stories.append(story)

        return list(filter(None, stories))
