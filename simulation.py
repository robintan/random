def unistr( array ):
	''' unicode to str '''
	return ', '.join( array )

class Scorer():
	def __init__(self):
		self.valueMap = self._generateValueMap()

	def getValue(self, card):
		rank = card.split()[ 0 ]
		return self.valueMap[ rank ]

	def handValue(self, hand):
		return reduce( lambda a, b: (a + b) % 10, map( self.getValue, hand ) )

	def _generateValueMap(self):
		valueMap = { u'A' : 1 }
		valueMap.update( dict( (unicode(i), i) for i in xrange(2, 11)) )
		valueMap.update( dict( (unicode(i), 0) for i in [ 'J', 'Q', 'K' ] ) )
		return valueMap

class Game():
	def __init__(self, useFigure=False, numOfDecks=10, maxNumOfBoard=80):
		self.useFigure = useFigure
		self.numOfDecks = numOfDecks
		self.maxNumOfBoard = maxNumOfBoard
		self.scorer = Scorer()

	def _generateDeck(self, useFigure=False):
		suits = [ u'\u2660', u'\u2665', u'\u2663', u'\u2666' ] if useFigure else [ u'S', u'H', u'C', u'D' ]
		ranks = [ u'A' ] + map( unicode, list( xrange( 2, 11 ) ) ) + [ u'J', u'Q', u'K' ]
		return [ rank + ' ' + suit for suit in suits for rank in ranks ]

	def _generateCards(self, useFigure, numOfDecks):
		deck = self._generateDeck( useFigure )

		def randomize( array ):
			import random
			new_array = array[:]
			random.shuffle( new_array )
			return new_array

		return reduce( lambda a,b : a + b, [ randomize( deck ) for i in xrange( numOfDecks ) ] )

	def _drawThirdCard(self, player, banker):
		playerValue = self.scorer.handValue( player )
		bankerValue = self.scorer.handValue( banker )

		if playerValue < 8 and bankerValue < 9:

			if playerValue <= 5:
				playerThirdCard = self.cards.pop()
				player.append( playerThirdCard )

				thirdCardValue = self.scorer.getValue( playerThirdCard )

				if bankerValue <= 2:
					banker.append( self.cards.pop() )
				elif bankerValue == 3 and thirdCardValue != 8:
					banker.append( self.cards.pop() )
				elif bankerValue == 4 and 2 <= thirdCardValue <= 7:
					banker.append( self.cards.pop() )
				elif bankerValue == 5 and 4 <= thirdCardValue <= 7:
					banker.append( self.cards.pop() )
				elif bankerValue == 6 and 6 <= thirdCardValue <= 7:
					banker.append( self.cards.pop() )

			else:
				if bankerValue <= 5:
					banker.append( self.cards.pop() )

	def drawCards(self):
		player = []
		banker = []

		player.append( self.cards.pop() )
		banker.append( self.cards.pop() )
		player.append( self.cards.pop() )
		banker.append( self.cards.pop() )

		self._drawThirdCard( player, banker )

		return player, banker

	def gameResult(self, playerHand, bankerHand):
		playerHandValue = self.scorer.handValue( playerHand )
		bankerHandValue = self.scorer.handValue( bankerHand )
		
		return self._result( playerHandValue, bankerHandValue )

	def _result(self, playerHandValue, bankerHandValue):
		result = 'TIE'
		if playerHandValue > bankerHandValue:
			result = 'PLAYER_FAB_4' if playerHandValue == 4 else 'PLAYER'
		elif bankerHandValue > playerHandValue:
			result = 'BANKER_FAB_4' if bankerHandValue == 4 else 'BANKER'

		return result

	def doSimulation(self):
		self.cards = self._generateCards( self.useFigure, self.numOfDecks )

		gameResults = []
		for i in xrange( 1, self.maxNumOfBoard + 1 ):
			p, b = self.drawCards()
			result = self.gameResult( p, b )
			gameResults.append( ( result, p, b ) )

		return gameResults

NUM_OF_SIMULATION = 50

game = Game()
gameResults = [ i for _ in xrange( NUM_OF_SIMULATION ) \
				  for i in game.doSimulation() ]

for i in gameResults:
	print i[0], unistr( i[1] ) , unistr( i[2] )
