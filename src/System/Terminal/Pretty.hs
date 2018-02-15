{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
module System.Terminal.Pretty
  ( -- * Pretty Printing
    TermDoc
  , TermStyle (..)
  , putDoc
  , putDocLn

    -- * Colors
    -- ** color
  , color
    -- ** onColor
  , onColor
    -- ** Standard Colors
  , black
  , red
  , green
  , yellow
  , blue
  , magenta
  , cyan
  , white
  ) where

import           Data.Semigroup
import           Data.String
import qualified Data.Text                 as Text
import qualified Data.Text.Prettyprint.Doc as PP

import qualified System.Terminal.Class     as T
import           System.Terminal.Color

type TermDoc = PP.Doc TermStyle

data TermStyle
  = TermForeground Color
  | TermBackground Color
  | TermInverted
  | TermUnderlined
  deriving (Eq, Ord, Show)

putDocLn :: (T.MonadColorPrinter m, T.MonadIsolate m) => TermDoc -> m ()
putDocLn doc = putDoc $ doc <> PP.hardline

putDoc :: (T.MonadColorPrinter m, T.MonadIsolate m) => TermDoc -> m ()
putDoc doc = T.isolate $ do
  T.setDefault
  render [] sdoc >> T.flush
  where
    width   = PP.AvailablePerLine 20 0.4
    options = PP.defaultLayoutOptions { PP.layoutPageWidth = width }
    sdoc = PP.layoutSmart options doc
    render anns = \case
      PP.SFail           -> fail "FAIL"
      PP.SEmpty          -> pure ()
      PP.SChar c ss      -> T.putChar c >> render anns ss
      PP.SText _ t ss    -> T.putText t >> render anns ss
      PP.SLine n ss      -> T.putLn >> T.putText (Text.replicate n " ") >> render anns ss
      PP.SAnnPush ann ss -> case ann of
        TermForeground c -> T.setForegroundColor c >> render (ann:anns) ss
        TermBackground c -> T.setBackgroundColor c >> render (ann:anns) ss
        TermInverted     -> T.setNegative True     >> render (ann:anns) ss
        TermUnderlined   -> T.setUnderline True    >> render (ann:anns) ss
      PP.SAnnPop ss      -> case anns of
        []                       -> render [] ss
        (TermForeground c:anns') -> T.setForegroundColor ColorDefault >> render anns' ss
        (TermBackground c:anns') -> T.setBackgroundColor ColorDefault >> render anns' ss
        (TermInverted    :anns') -> T.setNegative False    >> render anns' ss
        (TermUnderlined  :anns') -> T.setUnderline False   >> render anns' ss

color   :: Color -> TermDoc -> TermDoc
color c = PP.annotate (TermForeground c)

onColor :: Color -> TermDoc -> TermDoc
onColor c  = PP.annotate (TermBackground c)